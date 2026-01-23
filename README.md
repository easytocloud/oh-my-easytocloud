# oh-my-easytocloud

oh-my-easytocloud is an oh-my-zsh theme to spice-up your command prompt.

It is 95% identical to agnoster, just some different color scheme and support for 
AWS environments in your prompt.

## AWS Environments

AWS environments are an organizational system for managing multiple sets of AWS configuration and credential files on a single computer. They are stored in `~/.aws/aws-envs/` where each subdirectory represents a separate environment containing AWS `config` and/or `credentials` files.

This allows you to:
- Maintain different configurations for different customers
- Separate production from non-production environments
- Quickly switch between different AWS setups

You can switch environments using `ase <env-name>` which by default creates symlinks from the standard AWS config files (`~/.aws/config` and `~/.aws/credentials`) to the files in the specified environment. Alternatively, use `ase <env-name> env` to set the `AWS_CONFIG_FILE` environment variable to point to the config file in that environment.

The AWS part of the prompt displays a cloud icon on an (AWS) orange background together with the value of your `$AWS_PROFILE` environment variable and optionally `$AWS_ENV`.
Should you have a `$AWS_PROMPT` variable set, it will be displayed instead.

### Direct Credentials Display

When using direct AWS credentials (e.g., from SSO login or IAM user keys), the prompt intelligently displays credential information:

- **ASIA keys** (temporary SSO/STS credentials): Shows `☁ ASIA|<role>@<account>`
  - Extracts the role name from SSO assumed roles (e.g., `_cloudX` from `AWSReservedSSO__cloudX_...`)
  - Matches the account ID against profiles in your AWS config to display a friendly account name

- **AKIA keys** (IAM user long-term credentials): Shows `☁ AKIA|<username>@<account>`
  - Extracts the IAM username from the ARN
  - Matches the account ID to display the account name

The account name is derived from your AWS config file by matching the `sso_account_id` against profiles in the format `<role>@<account>`. If no matching profile is found, the last 4 digits of the account ID are displayed (e.g., `**3720`).

## Installation

Install with a single command:

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/easytocloud/oh-my-easytocloud/main/install.sh)"
```

The installer will:
- Download the theme and plugin files
- Automatically configure your `~/.zshrc` with the easytocloud theme
- Add the easytocloud plugin to your plugins list
- Create a backup of your `.zshrc` as `.zshrc.bak`

After installation, restart your terminal or run `source ~/.zshrc`.

## AWS Commands

The easytocloud plugin extends the standard AWS plugin with additional commands for managing AWS environments:

### Environment Commands
- `ase <env-name> [link|env]` - AWS Set Environment (with tab completion)
  - `link` (default): Creates global symlinks to environment config/credentials
  - `env`: Sets environment variables for current shell only
- `age` - AWS Get Environment (shows current environment)
- `acc` - AWS Clear Credentials (removes all AWS credential variables)

### Standard AWS Plugin Commands
The plugin also includes all commands from the standard oh-my-zsh AWS plugin:
- `asp <profile>` - AWS Set Profile
- `agp` - AWS Get Profile
- `asr <region>` - AWS Set Region (with tab completion)
- `agr` - AWS Get Region
- `aws_profiles` - List available profiles

## Variables

The theme uses the following variables to display information in the prompt:

``AWS_PROMPT`` - if set to anything other than an empty string, the value of this variable is displayed in the prompt

<img src="screenshots/pic1.png" width="700" >

In the example above, first AWS_PROFILE is not set, hence the aws command fails. 
Then AWS_PROFILE is set, the prompt displays the value of AWS_PROFILE and the aws cli command works.
Next, AWS_PROMPT is set to "Dev[factory]" and the aws cli command is run again. The prompt now displays "Dev[factory]" instead of the AWS_PROFILE value.
Notice how this has no effect on the AWS_PROFILE environment variable itself.

``AWS_ENV`` - if set to anything other than an empty string, the value of this variable is displayed in the prompt after the AWS_PROFILE value.

<img width="700" alt="Screenshot 2022-11-13 at 14 27 59" src="https://user-images.githubusercontent.com/11883816/201524287-460a291d-aa27-45e9-8a66-1e8ab5649ad3.png">

In the screenshot above you see the default profile is active in the training environment.
It also showcases our [privpage](https://github.com/easytocloud/privpage) aws cli integration to hide sensitive information in cli output!
