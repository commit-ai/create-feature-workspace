1. 1-time workspace setup, and the ability to create new branches in the same workspace (transition to a new "feature")
2. Change `branch` to `base_branch`
3. Demo it with the superheros repo's backend, frontend, etc. (from the exercises)
4. Agent skill for generating a workspace based on a ticket/spec by searching the current folder and the repos in it
5. Hook/skill for pulling all the remote base branches of all repos in the workspace
6. Add optional flag for branch separately from workspace name
7. Skills/plugins for the agent to work **with** the workspace, not just manipulate the workspace itself (wrap the `create-feature-workspace` command), and have the command copy/install the skills/plugins automatically when it creates it:
    1. Track/locate functionality (like code graph)
    2. Focus/fetch on a specific repo
    3. Wrap-up (create GitHub/BitBucket PRs for all the repos to their respective remote base branch) user-activated-only
8. Add general explanation about worktrees in a separate markdown file and mention it in `README.md`
