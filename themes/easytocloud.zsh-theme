#!/usr/bin/env zsh
# vim:ft=zsh ts=2 sw=2 sts=2
#
# easytocloud Theme
# Based on agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH with AWS environment support
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://github.com/Lokaltog/powerline-fonts).
#
# # Features
#
# - Shows AWS profile with environment, highlights production profiles in red
# - Sets terminal title to show AWS profile and current directory
# - Git branch and dirty state
# - Virtualenv support
# - Background jobs and error indicators

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'

case ${SOLARIZED_THEME:-dark} in
    light) CURRENT_FG='white';;
    *)     CURRENT_FG='black';;
esac

# Ultra-fast AWS cache with environment-based invalidation
_AWS_CACHE_KEY=""
_AWS_CACHE_VALUE=""
_AWS_CONFIG_CACHE=""

# Clear AWS cache (for testing)
clear_aws_cache() {
  _AWS_CACHE_KEY=""
  _AWS_CACHE_VALUE=""
  _AWS_CONFIG_CACHE=""
}

# Special Powerline characters

() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  # NOTE: This segment separator character is correct.  In 2012, Powerline changed
  # the code points they use for their special characters. This is the new code point.
  # If this is not working for you, you probably have an old version of the
  # Powerline-patched fonts installed. Download and install the new version.
  # Do not submit PRs to change this unless you have reviewed the Powerline code point
  # history and have new information.
  # This is defined using a Unicode escape sequence so it is unambiguously readable, regardless of
  # what font the user is viewing this source code in. Do not replace the
  # escape sequence with a single literal character.
  # Do not change this! Do not make it '\u2b80'; that is the old, wrong code point.
  SEGMENT_SEPARATOR=$'\ue0b0'
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
    echo -n "\n%{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n " %{%k%}"
    echo -n "\n%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment 13 default "%(!.%{%F{yellow}%}.)%n"
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  (( $+commands[git] )) || return
  if [[ "$(git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]]; then
    return
  fi
  local PL_BRANCH_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$'\ue0a0'         # 
  }
  local ref dirty mode repo_path

   if [[ "$(git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]]; then
    repo_path=$(git rev-parse --git-dir 2>/dev/null)
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    if [[ -n $dirty ]]; then
      prompt_segment yellow black
    else
      prompt_segment green $CURRENT_FG
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      mode=" >M<"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr '✚'
    zstyle ':vcs_info:*' unstagedstr '±'
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info
    echo -n "${ref/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
  fi
}

# Dir: current working directory
prompt_dir() {
  prompt_segment 39 $CURRENT_FG '%~'
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment blue black "(`basename $virtualenv_path`)"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local -a symbols

  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}✘"
  [[ $UID -eq 0 ]] && symbols+="%{%F{yellow}%}⚡"
  local job_count=$(jobs | wc -l)
  [[ $job_count -gt 0 ]] && symbols+="%{%F{cyan}%}⚙"

  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

# Lightning-fast AWS info lookup
get_aws_account_info() {
  local cache_key="${AWS_ACCESS_KEY_ID:-}:${AWS_SECRET_ACCESS_KEY:-}:${AWS_SESSION_TOKEN:-}:${AWS_PROFILE:-}:${AWS_CONFIG_FILE:-}"

  # Instant return if cache hit
  [[ "$_AWS_CACHE_KEY" == "$cache_key" ]] && echo "$_AWS_CACHE_VALUE" && return

  _AWS_CACHE_KEY="$cache_key"
  # Only call AWS API if we have direct credentials
  if [[ -n "$AWS_ACCESS_KEY_ID" ]]; then
    # Get both Account and Arn in one call
    local identity_json=$(aws sts get-caller-identity --output json 2>/dev/null)
    if [[ -n "$identity_json" ]]; then
      local account_id=$(echo "$identity_json" | awk -F'"' '/"Account"/ {print $4}')
      local arn=$(echo "$identity_json" | awk -F'"' '/"Arn"/ {print $4}')

      local role_name=""
      local account_name=""

      # Extract role/user name from ARN based on key type
      if [[ "$AWS_ACCESS_KEY_ID" == ASIA* && "$arn" == *:assumed-role/* ]]; then
        # ASIA keys: SSO/STS assumed roles
        # ARN format: arn:aws:sts::ACCOUNT:assumed-role/ROLE_NAME/SESSION
        local full_role="${arn##*:assumed-role/}"
        full_role="${full_role%%/*}"

        # For SSO roles, extract the meaningful part (e.g., _cloudX from AWSReservedSSO__cloudX_...)
        if [[ "$full_role" == AWSReservedSSO_* ]]; then
          # Pattern: AWSReservedSSO_ROLENAME_HASH - extract ROLENAME
          role_name="${full_role#AWSReservedSSO_}"
          role_name="${role_name%_[a-f0-9]*}"
        else
          role_name="$full_role"
        fi
      elif [[ "$AWS_ACCESS_KEY_ID" == AKIA* && "$arn" == *:user/* ]]; then
        # AKIA keys: IAM user long-term credentials
        # ARN format: arn:aws:iam::ACCOUNT:user/USERNAME
        role_name="${arn##*:user/}"
      fi

      # Cache config file content to avoid repeated I/O
      if [[ -z "$_AWS_CONFIG_CACHE" ]]; then
        local config_file="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
        [[ -L "$config_file" ]] && config_file="$HOME/.aws/$(readlink "$config_file")"
        [[ -f "$config_file" ]] && _AWS_CONFIG_CACHE=$(<"$config_file")
      fi

      # Try to find account name from config file
      # Profile format: <role>@<account>, so account_name is after @
      if [[ -n "$_AWS_CONFIG_CACHE" && -n "$account_id" ]]; then
        # Look for profiles with matching sso_account_id
        local profiles=(${(f)"$(echo "$_AWS_CONFIG_CACHE" | awk -v id="$account_id" '
          /^\[profile / { profile = $0; gsub(/^\[profile |\]$/, "", profile) }
          /^sso_account_id[ ]*=/ && $NF == id { print profile }
        ')"})

        if [[ ${#profiles[@]} -ge 1 ]]; then
          # Use last match (first matches may be special profiles like 'default' without @)
          # Profile format is <role>@<account>, extract account name (after @)
          if [[ "$profiles[-1]" == *@* ]]; then
            account_name="${profiles[-1]##*@}"
          else
            account_name="$profiles[-1]"
          fi
        fi
      fi

      # Build the display value in format: <role>@<account> to mimic profile names
      if [[ -n "$role_name" && -n "$account_name" ]]; then
        _AWS_CACHE_VALUE="${role_name}@${account_name}"
      elif [[ -n "$role_name" && -n "$account_id" ]]; then
        _AWS_CACHE_VALUE="${role_name}@**${account_id: -4}"
      elif [[ -n "$account_name" ]]; then
        _AWS_CACHE_VALUE="$account_name"
      elif [[ -n "$account_id" ]]; then
        _AWS_CACHE_VALUE="**${account_id: -4}"
      else
        _AWS_CACHE_VALUE=""
      fi
    else
      _AWS_CACHE_VALUE=""
    fi
  else
    _AWS_CACHE_VALUE=""
  fi

  echo "$_AWS_CACHE_VALUE"
}

# Optimized AWS prompt
prompt_aws() {
  [[ "$SHOW_AWS_PROMPT" = false ]] && return
  
  if [[ -n "$AWS_ACCESS_KEY_ID" && -n "$AWS_SECRET_ACCESS_KEY" ]]; then
    local account_info=$(get_aws_account_info)
    local aws_prompt=$'\u26C5'" ${AWS_ACCESS_KEY_ID:0:4}${account_info:+"|$account_info"}"
    prompt_segment 208 black "$aws_prompt"
    return
  fi
  
  [[ -z "$AWS_PROFILE$AWS_PROMPT" ]] && return
  
  local aws_prompt
  if [[ -n "$AWS_PROMPT" ]]; then
    aws_prompt="$AWS_PROMPT"
  else
    # Fast environment extraction without subshells
    env_name="${AWS_ENV:-}"
    aws_prompt=$'\u26C5'" $AWS_PROFILE${env_name:+"|$env_name"}"
  fi
  
  case "${aws_prompt:l}" in
    *main*|*prod*|*master*) prompt_segment 196 white "$aws_prompt" ;;
    *) prompt_segment 11 black "$aws_prompt" ;;
  esac
}

# Terminal title: show AWS profile/env info
set_terminal_title() {
  local title="%~"
  if [[ -n "$AWS_PROFILE" ]]; then
    title="${AWS_PROFILE}${AWS_ENV:+|$AWS_ENV} - %~"
  fi
  print -Pn "\e]0;${title}\a"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  prompt_status
  prompt_virtualenv
  prompt_aws
  prompt_context
  prompt_dir
  prompt_git
  prompt_end
}

# Cache AWS info in precmd to avoid subshell issues
precmd_aws_cache() {
  if [[ -n "$AWS_ACCESS_KEY_ID" && -n "$AWS_SECRET_ACCESS_KEY" ]]; then
    get_aws_account_info >/dev/null
  fi
}

precmd_functions+=(set_terminal_title precmd_aws_cache)
PROMPT='%{%f%b%k%}$(build_prompt) '
