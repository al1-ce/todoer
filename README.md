# todoer
A cli issue-based todo app that uses github for todo tracking (needs code changes since it uses this repo)

## Installing

## Usage

## Generating token

- Go to [Github Tokens](https://github.com/settings/tokens?type=beta) page
- Click `Generate new token`
- Give token any name and set expiration date
- In **Repository access** select `Only selected repositories` and select repository you want your todo tasks to be in
- Under **Permissions** select `Repository permissions` and set `Issues` to `Read and write`
- Review your changes if needed and click `Generate token`
- Copy generated token and create file in path `~/.ssh/git-todoer`, then paste token into newly created file
Now you can use todoer freely, please do not forget that giving out your github tokens might be dangerous.

