#
# easytocloud modification to default aws plugin


export ZSH_THEME_AWS_PROFILE_PREFIX="%K{11}%F{black} "
export ZSH_THEME_AWS_PROFILE_SUFFIX=""
export ZSH_THEME_AWS_DIVIDER=" | "

SHOW_AWS_PROMPT=false
source ${ZSH:-${HOME}/.oh-my-zsh}/plugins/aws/aws.plugin.zsh

# some getters
function age() {

    local _aws_env
    _aws_env=$(echo ${AWS_CONFIG_FILE:-$(readlink ~/.aws/config)} | rev |  cut -f2 -d '/' | rev)
    if [[ "$_aws_env" == ".aws" ]]; then
         _aws_env=""
    fi
    echo $_aws_env
}

function aws_environments(){
    ls ~/.aws/aws-envs
}

function ase(){
    # check for existance of ~/.aws/aws-envs
    if [[ ! -d ~/.aws/aws-envs ]]; then
        echo "${fg[red]}No AWS environments found. Please create ~/.aws/aws-envs directory and add your environments."
        return 1
    fi
    local -a available_environments
    available_environments=($(aws_environments))
    if [[ -z "${available_environments[(r)$1]}" ]]; then
        echo "${fg[red]}Available environments: \n$(aws_environments)"
        return 1
    fi
    # check that ~/.aws/config AND ~/.aws/credentials are symlinks
    if [[ ! -L ~/.aws/config || ! -L ~/.aws/credentials ]]; then
        echo "${fg[red]}~/.aws/config and ~/.aws/credentials must be symlinks"
        return 1
    fi
    
    # Set AWS environment

    local method
    AWS_ENV=$1

    method=${2:-"link"}
    if [[ "$method" == "link" ]]
	then
		(
			cd ~/.aws
			rm config credentials
			ln -s aws-envs/${AWS_ENV}/config ~/.aws/config
			ln -s aws-envs/${AWS_ENV}/credentials ~/.aws/credentials
		)
		unset AWS_CONFIG_FILE
		unset AWS_SHARED_CREDENTIALS_FILE
	else
		export AWS_CONFIG_FILE=~"/.aws/aws-envs/${AWS_ENV}/config" 
		export AWS_SHARED_CREDENTIALS_FILE=~"/.aws/aws-envs/${AWS_ENV}/credentials" 
	fi

    # Set AWS_PROFILE
    # if a 'default' profile exists in the environment, use it
    # else use the first profile in the environment
    if aws_profiles | grep -q '^default$'
    then
        export AWS_PROFILE=default
    else
        export AWS_PROFILE=$(aws_profiles | head -n 1)
    fi

    # awsenv $1
}

function _aws_environments(){
    reply=($(aws_environments))
}
compctl -K _aws_environments ase
# override AWS prompt
function aws_prompt_info() {
  local _aws_to_show
  local region="${AWS_REGION:-${AWS_DEFAULT_REGION:-$AWS_PROFILE_REGION}}"

  if [[ -n "$AWS_PROFILE" ]];then
    _aws_to_show+="${ZSH_THEME_AWS_PROFILE_PREFIX="<aws:"}${AWS_PROFILE}${ZSH_THEME_AWS_PROFILE_SUFFIX=">"}"
  fi

  local _AE=$(age)
  if [[ -n "$_AE" ]]; then
    _aws_to_show+="${ZSH_THEME_AWS_DIVIDER="|"}${_AE} %k%f"
  fi

  #if [[ -n "$region" ]]; then
  #  [[ -n "$_aws_to_show" ]] && _aws_to_show+="${ZSH_THEME_AWS_DIVIDER=" "}"
  #  _aws_to_show+="${ZSH_THEME_AWS_REGION_PREFIX="<region:"}${region}${ZSH_THEME_AWS_REGION_SUFFIX=">"}"
  #fi

  echo "$_aws_to_show"
}
