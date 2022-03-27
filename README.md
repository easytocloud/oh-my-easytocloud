# oh-my-cloud9
Upgrade cloud9 to use oh-my-zsh with informative prompt for your terminal

AWS Cloud9 uses bash by default. Comming from a Mac I am now used to zsh and I want to have a consistent experience developing local on my Mac and when using Cloud9. To achive this, one has to install zsh in the Cloud9 environment. And who says zsh says oh-my-zsh, right!?

oh-my-zsh uses themes to spice your command promt. Some of the themes require additional fonts. The fonts have to be installed *and* Cloud9 has to be configured to use them

So here's a quick script to do all of that. It comes with our own theme that puts AWS_DEFAULT_PROFILE and AWS_DEFAULT_ENV in your prompt. These can be set by you, or by a set of our tools that might not be all that relevant in Cloud9.
