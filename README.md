# github2enterprise

Move **GitHub.com** public things to a private **GitHub:Enterprise** instance. This tool will recreate **Labels**, **Milestones** and **Issues** from a repository on GitHub.com.

It uses [octokit.rb](https://github.com/octokit/octokit.rb) to post to your GitHub:Enterprise API, but it's not perfect:

* You'll lose native dates on Issues. The script will append the original date in a note on the issue body.
* You'll lose Pull Requests. Issues that were converted to Pull Request will again be issues.
* You'll lose commits attached to issues. The script will append a list of commits in the issue body.
* Comments are posted in the order they appear (by the original poster), though there's no way to tell if comments came after an issue was closed.
* Closing an issue with happen after all comments are posted. There's no history of re-opening an issue.

Make no assumptions that this will be a direct port of GitHub.com - it's designed to bring over the content but won't be an accurate history of activity.

This also assumes that the destination repository has been set up and includes all collaborators.


## Configuring

Most of the configuration is done in `config.rb`. I've included the sample format, so you'll want to do this:

```
$ cp config.sample.rb config.rb
```

As a GitHub:Enterprise admin, you'll need to log in as each collaborator and create a Personal Access token. This will allow the script to post issues and comments on a collaborator's behalf.


### Usage

Once configured, the script includes a short usage guide.

```
$ ruby g2e.rb --help

      --notifications    Unsubscribe each user from GitHub:Enterprise notifications
      --milestones       Mirror GitHub.com Milestones to GitHub:Enterprise
      --labels           Mirror GitHub.com Labels to GitHub:Enterprise
  -i, --issues ISSUES    Mirror GitHub.com ISSUES to GitHub:Enterprise
  -v, --verbose          Enable verbose logging.
      --test             Run this script in test mode.
  -d, --delay DELAY      Wait DELAY seconds between each API interaction.
      --help             This help dialog. See 'config.rb' for additional configuration.

```

It's not designed to do a mass import, rather label, milestones and issues are posted more deliberately.

`--test` will pull from GitHub.com, log what will happen, but it won't actually post to GitHub:Enterprise.

#### Notifications

As each collaborator, stop watching the destination repository. This will prevent them from being inundated with emails when issues are filed.

```
$ ruby g2e.rb --notifications
```

#### Milestones

This will create milestones, making sure to delete any missing milestones so the ID numbers stay in sync.

```
$ ruby g2e.rb --milestones
```

#### Labels

Posting issues will automatically create any nonexistent **Labels**, though this feature will include the original color associated with the label.

```
$ ruby g2e.rb --labels
```

#### Issues

```
$ ruby g2e.rb --issues [X]
```

The **Issues** feature accepts a single issue (`--issues 1`), a list of issues (`--issues 1,2,3`), or a range of issues (`--issues 1-10`).

Be mindful when using a list of issues (`1,3`) would create Issue #1 and #2.

