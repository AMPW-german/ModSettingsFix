#!/usr/bin/env bash
#
# new-mod.sh — create a new Kitten Space Agency code mod from KSAModTemplate.
#
#   bash new-mod.sh                     clone the template into <parent>/<ModName>
#   bash new-mod.sh   (inside a repo)   rework an unrenamed template clone in place
#                                       (e.g. one created with GitHub's
#                                       "Use this template" button)
#
# The script asks for a mod name (plus optional author, company and description),
# renames the project, replaces the git history with a single fresh commit so the
# result is not a fork of the template, and — after confirmation — creates and
# pushes a new GitHub repository.
#
# Requirements: git, bash (Git Bash on Windows). The gh CLI is only needed if you
# let the script create the GitHub repository.
#
# Env overrides:
#   KSA_MOD_TEMPLATE_REPO   template clone URL
#                           (default: https://github.com/AMPW-german/KSAModTemplate.git)

set -euo pipefail

TEMPLATE_REPO="${KSA_MOD_TEMPLATE_REPO:-https://github.com/AMPW-german/KSAModTemplate.git}"
TEMPLATE_NAME="$(basename "${TEMPLATE_REPO%.git}")"
KSAMODTOOLS_URL="https://github.com/AMPW-german/KSAModTools.git"
PLACEHOLDER="TemplateMod"

die() { echo "error: $*" >&2; exit 1; }

[[ -t 0 ]] || die "this script needs an interactive terminal for its prompts"
command -v git  >/dev/null || die "git is required"
command -v sed  >/dev/null || die "sed is required"
command -v grep >/dev/null || die "grep is required"

# --- where are we? ---------------------------------------------------------
# clone                  no template checkout here -> clone TEMPLATE_REPO
# inplace-template       inside a clone of the template repo itself
# inplace-foreign        inside a repo generated from the template (e.g. via
#                        GitHub's "Use this template"), which has its own remote
MODE=clone
TARGET=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	TOPLEVEL="$(git rev-parse --show-toplevel)"
	if [[ -f "$TOPLEVEL/$PLACEHOLDER/$PLACEHOLDER.csproj" ]]; then
		TARGET="$TOPLEVEL"
		ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"
		if [[ "$ORIGIN_URL" == *"$TEMPLATE_NAME"* ]]; then
			MODE=inplace-template
		else
			MODE=inplace-foreign
		fi
	fi
fi

# --- mod name ---------------------------------------------------------------
DEFAULT_MOD=""
if [[ "$MODE" != clone ]]; then
	DEFAULT_MOD="$(basename "$TARGET")"
fi
[[ "$DEFAULT_MOD" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || DEFAULT_MOD=""

while true; do
	read -r -p "Mod name — letters, digits, underscore [${DEFAULT_MOD:-required}]: " MOD_NAME
	MOD_NAME="${MOD_NAME:-$DEFAULT_MOD}"
	[[ "$MOD_NAME" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && break
	echo "  invalid — use letters, digits and underscores, not starting with a digit."
done

# --- target directory -------------------------------------------------------
if [[ "$MODE" == clone ]]; then
	read -r -p "Parent directory for the new repository: " PARENT
	PARENT="${PARENT/#\~/$HOME}"
	[[ "$PARENT" =~ ^[A-Za-z]: ]] && PARENT="$(cygpath -u "$PARENT")"
	[[ -d "$PARENT" ]] || die "directory does not exist: $PARENT"
	TARGET="$PARENT/$MOD_NAME"
	[[ ! -e "$TARGET" ]] || die "$TARGET already exists"
fi

# --- metadata ---------------------------------------------------------------
GIT_NAME="$(git config user.name 2>/dev/null || true)"
read -r -p "Author [${GIT_NAME:-none}]: " AUTHOR
AUTHOR="${AUTHOR:-$GIT_NAME}"
read -r -p "Company [${AUTHOR:-none}]: " COMPANY
COMPANY="${COMPANY:-$AUTHOR}"
read -r -p "Description [A Kitten Space Agency mod.]: " DESCRIPTION
DESCRIPTION="${DESCRIPTION:-A Kitten Space Agency mod.}"

git config user.email >/dev/null 2>&1 || die "git user.email is not configured (needed for the initial commit)"
git config user.name  >/dev/null 2>&1 || die "git user.name is not configured (needed for the initial commit)"

# --- GitHub repo details (not needed when pushing to an existing remote) -----
GH_REPO=""
GH_VIS="private"
if [[ "$MODE" != inplace-foreign ]]; then
	read -r -p "GitHub repository name [${MOD_NAME}]: " GH_REPO
	GH_REPO="${GH_REPO:-$MOD_NAME}"
	read -r -p "Repository visibility [private]: " GH_VIS
	GH_VIS="$(printf '%s' "${GH_VIS:-private}" | tr '[:upper:]' '[:lower:]')"
	[[ "$GH_VIS" == public ]] || GH_VIS="private"
fi

# --- obtain the working copy -----------------------------------------------
if [[ "$MODE" == clone ]]; then
	echo "==> cloning $TEMPLATE_REPO"
	git clone --recurse-submodules "$TEMPLATE_REPO" "$TARGET"
fi
cd "$TARGET"

# The tooling/ submodule must be checked out for the MSBuild imports to resolve.
# "Use this template" clones may lack the gitlink, so fall back to re-adding it.
git submodule update --init --recursive >/dev/null 2>&1 || true
if [[ ! -f tooling/msbuild/KsaMod.props ]]; then
	echo "==> tooling submodule missing — adding KSAModTools"
	git submodule deinit -f tooling >/dev/null 2>&1 || true
	rm -rf tooling .git/modules/tooling
	rm -f .gitmodules
	git submodule add -b main "$KSAMODTOOLS_URL" tooling
fi

# --- rename ------------------------------------------------------------------
mv "$PLACEHOLDER" "$MOD_NAME"
mv "$PLACEHOLDER.slnx" "$MOD_NAME.slnx"
mv "$MOD_NAME/$PLACEHOLDER.csproj" "$MOD_NAME/$MOD_NAME.csproj"

esc() { printf '%s' "$1" | sed 's/[&|\\]/\\&/g'; }

grep -rl --exclude-dir=.git --exclude-dir=tooling --exclude=new-mod.sh "$PLACEHOLDER" . \
	| while IFS= read -r f; do sed -i "s/${PLACEHOLDER}/${MOD_NAME}/g" "$f"; done

sed -i \
	-e "s|<Company></Company>|<Company>$(esc "$COMPANY")</Company>|" \
	-e "s|<Authors></Authors>|<Authors>$(esc "$AUTHOR")</Authors>|" \
	-e "s|<Description>.*</Description>|<Description>$(esc "$DESCRIPTION")</Description>|" \
	"$MOD_NAME/$MOD_NAME.csproj"

# The template's own UNLICENSE must not leak into generated repos.
rm -f UNLICENSE

cat > README.md <<EOF
# $MOD_NAME

$DESCRIPTION

A [Kitten Space Agency](https://kittenspaceagency.com) (KSA) code mod built on
[KSAModTools](https://github.com/AMPW-german/KSAModTools) and
[StarMap](https://github.com/StarMapLoader/StarMap).

## Layout

- \`$MOD_NAME/$MOD_NAME.csproj\` — the mod project (imports \`tooling/msbuild/KsaMod.props\` / \`KsaMod.targets\`)
- \`$MOD_NAME/Mod.cs\` — \`[StarMapMod]\` entry point: applies Harmony patches and draws the welcome window
- \`$MOD_NAME/Patches.cs\` — example Harmony prefix patch
- \`tooling/\` — KSAModTools submodule (MSBuild props/targets and CI actions)
- \`.github/workflows/build.yml\` — CI: builds, packages and releases the mod

## Build locally

Requires the .NET 10 SDK and the KSA game files — either a local install
(default \`C:\Program Files\Kitten Space Agency\`, override with \`KSA_DIR\` /
\`KSADir\`) or a KSADLLs snapshot via \`KSA_DLL_REPO_DIR\` with
\`UseKsaNuGetPackages=true\`. StarMap.API is referenced from a StarMap install
in your KSA mods folder (\`StarMap/StarMap.API.dll\`, override with \`KSA_MODS_DIR\`).

\`\`\`sh
dotnet build -c Release
\`\`\`

The build packages the mod into \`Release/$MOD_NAME/\` and copies it into your
local KSA mods folder automatically.

## CI

\`.github/workflows/build.yml\` ships with automatic triggers disabled
(\`workflow_dispatch\` only) so it does nothing until secrets are configured.
To enable it, uncomment the \`push\`/\`pull_request\` triggers and set up:

| Secret / variable | Purpose |
| --- | --- |
| \`KSADLLRepo\` (secret) | \`owner/repo\` of a private KSA DLL snapshot repo (game DLLs + \`ksa-versions.csv\` + \`KsaNuGet.props\`; KSAModTools' \`scripts/update_ksa_dlls.py\` generates one) |
| \`KSA_DLL_TOKEN\` (secret) | PAT with read access to that repo — simpler alternative to the App below |
| \`APP_ID\` + \`APP_PRIVATE_KEY\` (secrets) | GitHub App credentials for the DLL repo, alternative to \`KSA_DLL_TOKEN\` |
| \`SPACEDOCKUSERNAME\` (variable) | your SpaceDock username |
| \`SPACEDOCKAUTH\` (secret) | your SpaceDock API token |
| \`SPACEDOCK_ID\` | set in \`build.yml\` — your mod's SpaceDock ID |

On pushes to \`main\` that change \`VersionPrefix\`, the workflow also publishes a
GitHub release and uploads the package to SpaceDock.

Generated from [KSAModTemplate](https://github.com/AMPW-german/KSAModTemplate).
EOF

# --- fresh history ------------------------------------------------------------
# An orphan branch gives a single root commit with no shared history, so the new
# repo is not connected to the template on GitHub. The submodule gitlink and
# .gitmodules survive because the index is kept.
git checkout --orphan fresh-start
git add -A
git commit -m "Initial commit"
git branch --format='%(refname:short)' | while IFS= read -r b; do
	[[ "$b" == fresh-start ]] || git branch -D "$b"
done
git tag -l | xargs -r git tag -d
TARGET_BRANCH="main"
if [[ "$MODE" == inplace-foreign ]]; then
	RB="$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || true)"
	[[ -n "$RB" ]] && TARGET_BRANCH="$RB"
fi
git branch -m "fresh-start" "$TARGET_BRANCH"
git config core.hooksPath tooling/githooks

# Never leave a remote pointing at the template repo — a stray 'git push' must
# not be able to hit it. inplace-foreign keeps its own (new) remote instead.
if [[ "$MODE" != inplace-foreign ]]; then
	git remote remove origin
fi

# --- summary + confirmation ---------------------------------------------------
echo
echo "==> prepared $MOD_NAME in $TARGET"
echo "    project : $MOD_NAME/$MOD_NAME.csproj"
echo "    branch  : $TARGET_BRANCH (single fresh commit, not a fork)"

case "$MODE" in
	inplace-foreign)
		ORIGIN_URL="$(git remote get-url origin)"
		echo "    remote  : $ORIGIN_URL — history will be replaced"
		read -r -p "Force-push the fresh history? [y/N] " CONFIRM
		;;
	*)
		echo "    github  : $GH_REPO ($GH_VIS) — will be created with 'gh repo create'"
		read -r -p "Create the GitHub repo and push? [y/N] " CONFIRM
		;;
esac

if [[ "${CONFIRM:-}" != [yY]* ]]; then
	echo "Stopped before pushing. The repo is ready — push it yourself when ready:"
	if [[ "$MODE" == inplace-foreign ]]; then
		echo "  git -C \"$TARGET\" push --force-with-lease -u origin $TARGET_BRANCH"
	else
		echo "  git -C \"$TARGET\" remote add origin <your-repo-url>"
		echo "  git -C \"$TARGET\" push -u origin $TARGET_BRANCH"
	fi
	exit 0
fi

# --- push ---------------------------------------------------------------------
if [[ "$MODE" == inplace-foreign ]]; then
	git push --force-with-lease -u origin "$TARGET_BRANCH"
else
	if ! command -v gh >/dev/null; then
		echo "gh CLI not found — create the repo manually:"
		echo "  git -C \"$TARGET\" remote add origin <your-repo-url>"
		echo "  git -C \"$TARGET\" push -u origin $TARGET_BRANCH"
		exit 0
	fi
	gh repo create "$GH_REPO" --"$GH_VIS" --source=. --remote=origin --push --description="$DESCRIPTION"
fi

cat <<EOF

Done — $MOD_NAME is ready.

Next steps:
  1. Build:   cd "$TARGET" && dotnet build -c Release
              (see README.md "Build locally" for requirements)
  2. Test:    the Release output is copied into your KSA mods folder on build.
  3. CI:      .github/workflows/build.yml is manual-only until you configure the
              secrets listed in README.md "CI setup" and enable its triggers.
  4. Hooks:   core.hooksPath is already set to tooling/githooks.
EOF
