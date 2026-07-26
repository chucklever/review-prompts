#!/bin/bash
#
# Setup script for AI-assisted code review prompts
#
# Installs skills and command prompts for the specified agent on their
# respective locations.
#
# Usage: ./setup.sh [OPTIONS] <agent> <project>
#
# Each project directory must contain a skill file at:
#   <project>/skills/<project>.md
#
# The skill filename is derived from the directory name (e.g. the "iproute"
# project uses iproute/skills/iproute.md).  Inside that file, use the
# placeholder {{<PROJECT>_REVIEW_PROMPTS_DIR}} (uppercased project name)
# for paths that should resolve to the project directory at install time.
#
# Command prompts live in <project>/slash-commands/*.md and may use
# {{REVIEW_DIR}} or {{<PROJECT>_REVIEW_PROMPTS_DIR}} as placeholders for the
# project directory path.  Agents can install them as slash commands, skills,
# or both.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
    echo "Usage: $0 [OPTIONS] <agent> <project>"
    echo "Setup script for AI-assisted code review prompts."
    echo "Installs skills and command prompts for the specified agent."
    echo ""
    echo "Arguments:"
    echo "  <agent>     Install skill and commands for this code agent"
    echo "              Available agents: claude, codex, opencode, gemini,"
    echo "                                goose, kiro-cli"
    echo "  <project>   Install skills and commands for this project"
    echo "              Available projects: iproute, kernel, systemd"
    echo ""
    echo "Options:"
    echo "  -h, --help  Show this help message and exit"
}

# Skill and slash commands installation process.
# Args: $1 = project
install_project() {
    local project="$1"
    local src_skill_fn="${project}.md"
    local project_dir="$SCRIPT_DIR/$project"
    local prompts_dir_var="${project^^}_REVIEW_PROMPTS_DIR"
    local command_prefix="${COMMAND_PREFIX:-/}"

    echo "--- Installing $project prompts ---"

    # Install skills from the source to the agent specific path
    local agent_skills_dir="$SKILL_BASE_DIR/$project"
    local agent_skill_path="$agent_skills_dir/$SKILL_FILE_NAME"
    local src_skill_path="$project_dir/skills/$src_skill_fn"

    if [ ! -f "$src_skill_path" ]; then
        echo "Error: Source skill file not found: $src_skill_path"
        exit 1
    fi

    mkdir -p "$agent_skills_dir"
    sed \
        -e "s|{{${prompts_dir_var}}}|$project_dir|g" \
        -e "s|{{REVIEW_DIR}}|$project_dir|g" \
        "$src_skill_path" > "$agent_skill_path"

    echo "Installed skill:"
    echo "  $agent_skill_path"

    # Install command prompts to the agent specific path
    local src_commands="$project_dir/slash-commands"

    if [ ! -d "$src_commands" ]; then
        echo "Warning: commands directory not found for $project, skipping"
    else
        if [ "${COMMANDS_AS_SKILLS:-0}" = "1" ]; then
            # The agent has no standalone slash-command files; install
            # each command as a skill (<name>/SKILL.md) so the agent
            # exposes it as <prefix><name>.  Skills require frontmatter
            # with a name, so generate it when the source file has none.
            echo ""
            echo "Installed command skills:"

            for cmd_file in "$src_commands"/*.md; do
                if [ -f "$cmd_file" ]; then
                    local cmd_name=$(basename "$cmd_file")
                    local cmd_skill_name="${cmd_name%.md}"
                    local cmd_skill_dir="$SKILL_BASE_DIR/$cmd_skill_name"
                    local cmd_skill_path="$cmd_skill_dir/$SKILL_FILE_NAME"
                    mkdir -p "$cmd_skill_dir"
                    {
                        if ! head -n 1 "$cmd_file" | grep -q '^---$'; then
                            printf -- '---\n'
                            printf 'name: %s\n' "$cmd_skill_name"
                            printf 'description: "%s%s slash command from the %s review prompts; load only when invoked explicitly"\n' \
                                "$command_prefix" "$cmd_skill_name" "$project"
                            printf -- '---\n\n'
                        fi
                        sed \
                            -e "s|{{${prompts_dir_var}}}|$project_dir|g" \
                            -e "s|{{REVIEW_DIR}}|$project_dir|g" \
                            "$cmd_file"
                    } > "$cmd_skill_path"
                    echo "  ${command_prefix}${cmd_skill_name}"
                fi
            done
        elif [ -n "${COMMANDS_DIR:-}" ]; then
            mkdir -p "$COMMANDS_DIR"

            echo ""
            echo "Installed slash commands:"

            for cmd_file in "$src_commands"/*.md; do
                if [ -f "$cmd_file" ]; then
                    local cmd_name=$(basename "$cmd_file")
                    sed \
                        -e "s|{{${prompts_dir_var}}}|$project_dir|g" \
                        -e "s|{{REVIEW_DIR}}|$project_dir|g" \
                        "$cmd_file" > "$COMMANDS_DIR/$cmd_name"
                    echo "  ${command_prefix}${cmd_name%.md}"
                fi
            done
        fi
    fi

    echo ""
}

# Handle args and flags
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    usage
    exit 0
fi

if [ "$#" -ne 2 ]; then
    echo "Error: expected 2 arguments (<agent> <project>), got $#"
    echo ""
    usage
    exit 1
fi

AGENT="$1"
PROJECT="$2"

AGENT_SCRIPT="$SCRIPT_DIR/agents/${AGENT}.sh"

if [ ! -f "$AGENT_SCRIPT" ]; then
    echo "Error: Setup script for agent '$AGENT' not found at $AGENT_SCRIPT"
    exit 1
fi

PROJECT_DIR="$SCRIPT_DIR/$PROJECT"
if [ ! -d "$PROJECT_DIR" ]; then
    echo "Error: Project '$PROJECT' not found at $PROJECT_DIR"
    exit 1
fi

# Load agent configuration
source "$AGENT_SCRIPT"

echo "Review prompts directory: $SCRIPT_DIR/$PROJECT"
echo "Setting up for agent: $AGENT"
echo "Setting up for project: $PROJECT"
echo ""

install_project "$PROJECT"

echo "Setup complete!"
echo ""
echo "The skills load automatically in their respective project trees."
