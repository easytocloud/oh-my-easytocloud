# oh-my-easytocloud

oh-my-easytocloud is an oh-my-zsh theme to spice-up your command prompt.

It is 95% identical to agnoster, just some different color scheme and support for 
AWS environments in your prompt.

AWS environments are part of [aws-profile-organizer](https://github.com/easytocloud/aws-profile-organizer)

Install the theme in the customs/themes directory of your oh-my-zsh installation (usually in ~/.oh-my-zsh).

```
wget https://raw.githubusercontent.com/easytocloud/oh-my-easytocloud/main/themes/easytocloud.zsh-theme -O ~/.oh-my-zsh/custom/themes/easytocloud.zsh-theme
```

or first clone this repo and then copy the theme file

```
git clone https://github.com/easytocloud/oh-my-easytocloud.git
cp oh-my-easytocloud/themes/easytocloud.zsh-theme ~/.oh-my-zsh/custom/themes
```

Change ZSH_THEME (eg. in ~/.zshrc) to read "easytocloud" and enjoy the new information in your prompt.

In the screenshot below you see the default profile is active in the training environment.
It also showcases our [privpage](https://github.com/easytocloud/privpage) aws cli integration to hide sensitive information in cli output!

<img width="701" alt="Screenshot 2022-11-13 at 14 27 59" src="https://user-images.githubusercontent.com/11883816/201524287-460a291d-aa27-45e9-8a66-1e8ab5649ad3.png">
