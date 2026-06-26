# brave-origin — Void Linux (xbps-src)

> Installe et met à jour **Brave Origin** (build non-Widevine) sur Void Linux via `xbps-src`.

---

## Contenu du dépôt

| Fichier | Rôle |
|---|---|
| `xbps-src.sh` | Prépare l'environnement `void-packages` (une seule fois) |
| `braveupdatexbps.sh` | Détecte la dernière version stable, met à jour le template, compile, installe |

---

## Dépendances système

> Installées automatiquement par `xbps-src.sh`.

| Paquet | Usage |
|---|---|
| `git` | Clone de `void-packages` |
| `base-devel` | Chaîne de compilation (gcc, make, binutils…) |
| `xtools-minimal` | Fournit `xi` (wrapper `xbps-install`) |
| `python3` | Requis par le bootstrap de `xbps-src` |

Dépendances runtime de `braveupdatexbps.sh` (déjà présentes sur Void en général) :

| Outil | Usage |
|---|---|
| `curl` | Appels à l'API GitHub et téléchargement du `.sha256` |
| `jq` | Parsing JSON de la réponse API |
| `doas` | Élévation de privilèges (remplace `sudo`) |

---

## Étape 1 — Préparer xbps-src

> **À faire une seule fois** après une nouvelle installation.

```sh
chmod +x xbps-src.sh
./xbps-src.sh
```

### Ce que fait le script

```
1. Installe git, base-devel, xtools-minimal, python3
2. Clone void-packages dans /opt/void-packages  (depth=1)
3. Fixe les permissions sur l'utilisateur courant
4. Lance le binary-bootstrap (masterdir)
5. Écrit etc/conf avec :
   - XBPS_ALLOW_RESTRICTED=yes    ← nécessaire pour les paquets binaires propriétaires
   - XBPS_CHROOT_CMD=uchroot
   - XBPS_CFLAGS="-march=native -O3 -pipe"
6. Ajoute l'utilisateur au groupe xbuilder
7. Met à jour le bootstrap et le cache système
8. Nettoie le repocache
```

> ⚠️ `xbps-src` **ne peut pas tourner en root**. Le script utilise `doas` uniquement pour les étapes qui l'exigent.

> ℹ️ Si `void-packages` existe déjà dans `/opt/`, commenter le `git clone` et décommenter la ligne `git clean -fd && git reset --hard && git pull`.

---

## Étape 2 — Installer / mettre à jour Brave Origin

```sh
chmod +x braveupdatexbps.sh
./braveupdatexbps.sh
```

### Ce que fait le script

```
1. [API]      Requête GitHub → liste des releases (per_page=50)
              Filtre : prerelease=false, draft=false, exclut Nightly/Beta/Dev
              Sélectionne la première (= la plus récente stable)

2. [SHA256]   Localise l'asset  brave-origin_*_amd64.deb.sha256
              Télécharge uniquement ce fichier (pas le .deb entier)
              Valide : longueur exacte 64 caractères hex

3. [TEMPLATE] Si /opt/void-packages/srcpkgs/brave/template absent :
                → Crée le template complet (do_extract + do_install)
              Sinon :
                → Compare version actuelle vs version GitHub
                → Si identique : exit 0  (rien à faire)
                → Sinon : patch version= et checksum= via sed
                          affiche le diff avant/après

4. [BUILD]    cd /opt/void-packages
              ./xbps-src -A x86_64 -f pkg brave

5. [INSTALL]  doas xi -Syuf brave
```

### Logs typiques d'une mise à jour

```
[*] Querying GitHub API...
[*] Latest stable version: 1.78.101
[*] File: brave-origin_1.78.101_amd64.deb.sha256
[*] Fetching checksum...
[*] SHA256: a3f9c1...e42b
[*] Updating: 1.77.97 → 1.78.101
[✓] Template updated!

── Diff ──────────────────────────────────────────────
< version=1.77.97
< checksum=9d2e...
---
> version=1.78.101
> checksum=a3f9...
──────────────────────────────────────────────────────

[*] Building package...
[*] Installing...
[✓] Brave Origin 1.78.101 successfully installed!
```

### Logs typiques si déjà à jour

```
[*] Querying GitHub API...
[*] Latest stable version: 1.78.101
[=] Already up to date (1.78.101). Nothing to do.
```

---

## Structure du template xbps-src généré

```
/opt/void-packages/srcpkgs/brave/template
```

```sh
pkgname=brave
version=<VERSION>
revision=2
only_for_archs="x86_64"
distfiles="https://github.com/brave/brave-browser/releases/download/v${version}/brave-origin_${version}_amd64.deb"
checksum=<SHA256>
nostrip=yes

do_extract()   # ar x .deb → extrait data.tar.xz
do_install()   # tar xf data.tar.xz → installe dans DESTDIR
               # déplace les icônes (24/32/48/64/128/256 px)
               # supprime /etc, /cron, /usr/share/doc, /usr/lib (débris Debian)
```

---

## Arborescence après installation

```
/opt/brave.com/brave-origin/
/usr/share/applications/brave-browser.desktop
/usr/share/icons/hicolor/{24,32,48,64,128,256}x*/apps/brave-browser.png
```

---

## Automatisation (optionnel)

Pour mettre à jour Brave automatiquement, ajouter dans `crontab -e` :

```cron
# Vérifie une mise à jour de Brave chaque jour à 8h
0 8 * * * /path/to/braveupdatexbps.sh >> /var/log/brave-update.log 2>&1
```

---

## Dépannage

| Symptôme | Cause probable | Solution |
|---|---|---|
| `xbps-src: cannot be used as root` | Lancé en root | Utiliser un utilisateur normal du groupe `xbuilder` |
| `[!] brave-origin .deb.sha256 not found` | GitHub a changé le nom de l'asset | Inspecter `braveupdatexbps.sh` → variable `SHA_NAME_PATTERN` |
| `[!] Invalid checksum (length=N)` | `.sha256` vide ou format modifié | Vérifier manuellement l'URL retournée |
| Build échoue sur `uchroot` | `uchroot` non installé ou SUID absent | `doas xbps-install xtools` + vérifier `/usr/lib/xbps/uchroot` |
| `doas: command not found` | `doas` absent | `xbps-install opendoas` et configurer `/etc/doas.conf` |

---

## Références

- [void-packages](https://github.com/void-linux/void-packages) — dépôt officiel des templates Void
- [brave-browser releases](https://github.com/brave/brave-browser/releases) — source des assets `.deb`
- [xbps-src manual](https://github.com/void-linux/void-packages/blob/master/Manual.md)
