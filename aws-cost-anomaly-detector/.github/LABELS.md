##############################################################################
# GitHub Labels — run once to create project labels:
# gh label create <name> --color <hex> --description "<desc>"
#
# Or use the GitHub CLI script at the bottom of this file.
##############################################################################

# ─── Infrastructure ──────────────────────────────────────────────────────────
# Name             Color     Description
# terraform        #5C4EE5   Terraform infrastructure changes
# infrastructure   #0075ca   AWS infrastructure related
# lambda           #FF9900   Lambda function changes
# iam              #d93f0b   IAM role/policy changes

# ─── CI / Quality ────────────────────────────────────────────────────────────
# ci-cd            #e4e669   GitHub Actions pipeline
# terraform-drift  #FBCA04   Infrastructure drift from Terraform state
# security         #d93f0b   Security-related findings

# ─── Standard ────────────────────────────────────────────────────────────────
# bug              #d73a4a   Something isn't working
# enhancement      #a2eeef   New feature or request
# documentation    #0075ca   Documentation improvements
# dependencies     #0366d6   Dependency updates from Dependabot
# triage           #e4e669   Needs triage
# urgent           #d73a4a   Requires immediate attention
# github-actions   #000000   GitHub Actions workflow update
# python           #3572A5   Python Lambda code changes

---

# ── Quick Setup Script ─────────────────────────────────────────────────────
# Run this once after creating the repo to set up all labels:
#
# gh label create "terraform"       --color "5C4EE5" --description "Terraform infrastructure changes"
# gh label create "infrastructure"  --color "0075ca" --description "AWS infrastructure related"
# gh label create "lambda"          --color "FF9900" --description "Lambda function changes"
# gh label create "iam"             --color "d93f0b" --description "IAM role/policy changes"
# gh label create "ci-cd"           --color "e4e669" --description "GitHub Actions pipeline"
# gh label create "terraform-drift" --color "FBCA04" --description "Infrastructure drift from Terraform state"
# gh label create "security"        --color "d93f0b" --description "Security-related findings"
# gh label create "urgent"          --color "d73a4a" --description "Requires immediate attention"
# gh label create "python"          --color "3572A5" --description "Python Lambda code changes"
