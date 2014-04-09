#!/usr/bin/ruby

@config = {
  # Your GitHub.com username
  :username => "[username]",

  # Your GitHub.com password or Personal Access token.
  :password => "[password|token]",

  # Your GitHub:Enterprise hostname (assumed to be HTTPS).
  :enterprise => "[git.example.com]",

  # The GitHub.com source repository.
  :source => "[organization]/[repository]",

  # The GitHub:Enterprise repository that should mirror GitHub.com
  :mirror => "[organization]/[repository]",

  # Define the list of GitHub:Enterprise users you'll log in as (to create and
  # close issues on thier behalf).
  :collaborators => {
    "[username]" => { :token => "[this user's personal access token]" },
    "[username]" => { :token => "[this user's personal access token]" },
    "ghost" =>      { :token => "486dfb25eaf446617c5d68d2335df922d43b8473" }
  },

  # The GitHub:Enterprise user who can do anything (like delete stuff).
  :admin => "flesch"

}
