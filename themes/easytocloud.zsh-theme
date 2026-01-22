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
    local account_id=$(aws sts get-caller-identity --query Account --output text 2>/dev/null)
    if [[ -n "$account_id" ]]; then
      # Cache config file content to avoid repeated I/O
      if [[ -z "$_AWS_CONFIG_CACHE" ]]; then
        local config_file="${AWS_CONFIG_FILE:-$HOME/.aws/config}"
        [[ -L "$config_file" ]] && config_file="$HOME/.aws/$(readlink "$config_file")"
        [[ -f "$config_file" ]] && _AWS_CONFIG_CACHE=$(<"$config_file")
      fi
      
      if [[ -n "$_AWS_CONFIG_CACHE" ]]; then
        # Ultra-fast string matching instead of grep/sed
        local profiles=(${(f)"$(echo "$_AWS_CONFIG_CACHE" | awk -v id="$account_id" '
          /^\[profile / { profile = $0; gsub(/^\[profile |\]$/, "", profile) }
          /^sso_account_id = / && $3 == id { print profile }
        ')"})
        
        if [[ ${#profiles[@]} -eq 1 ]]; then
          _AWS_CACHE_VALUE="$profiles[1]"
        elif [[ ${#profiles[@]} -gt 1 ]]; then
          # Fast common suffix extraction
          local suffix="${profiles[1]##*@}"
          [[ "$profiles[1]" == *@* ]] && _AWS_CACHE_VALUE="$suffix" || _AWS_CACHE_VALUE="**${account_id: -4}"
        else
          _AWS_CACHE_VALUE="**${account_id: -4}"
        fi
      else
        _AWS_CACHE_VALUE="**${account_id: -4}"
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
    local aws_prompt=$'\u26C5'" CREDS${account_info:+"|$account_info"}${AWS_SESSION_TOKEN:+"|STS"}"
    prompt_segment 208 black "$aws_prompt"
    return
  fi
  
  [[ -z "$AWS_PROFILE$AWS_PROMPT" ]] && return
  
  local aws_prompt
  if [[ -n "$AWS_PROMPT" ]]; then
    aws_prompt="$AWS_PROMPT"
  else
    # Fast environment extraction without subshells
    local env_name="${AWS_CONFIG_FILE##*/}"
    [[ "$env_name" == "config" ]] && env_name=""
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
