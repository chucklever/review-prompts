#!/bin/bash
#
# Agent setup script for Codex.
#
# Sourced by setup.sh to configure where skills and command workflows are
# installed. Codex invokes reusable local workflows as skills.

export SKILL_BASE_DIR="$HOME/.codex/skills"
export SKILL_FILE_NAME="SKILL.md"
export COMMANDS_AS_SKILLS="1"
export COMMAND_PREFIX='$'
