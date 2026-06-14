# Contributing to BDB Genomics

Thank you for considering contributing to BDB Genomics! Your help makes open-source bioinformatics more powerful and robust.

Our goal is to build the most rigorous, modular standard for epigenomic and transcriptomic data processing. We welcome all contributions, whether you are fixing a bug, adding a new utility, or improving documentation.

---

## How Can I Help?

### 1. Reporting Bugs & Suggestions
If you find a bug or have a feature idea:
- Check if an **Issue** already exists.
- If not, open a new one with details (logs, config, and example data).

### 2. Submitting Pull Requests (PRs)
To contribute code:
- **Fork** the repository and create a branch from `main`.
- **Develop** your isolated Snakemake rule (`.smk`) and its environment (`.yaml`).
- **Use Conda**: Ensure rules rely strictly on isolated environment descriptors.
- **Test**: Confirm your changes pass the `validate_config.py` check.
- **Open a PR**: Describe your changes and any new parameters clearly.

### 3. Improving Documentation
Bioinformatics is complex. If our guides are unclear or if you have a tutorial to share, please submit a documentation PR.

---

## Architecture Guidelines
- **Modularity**: Every tool must have its own `.smk` file and `.yaml` environment.
- **Fail Fast**: Build in checks to ensure the pipeline fails safely if inputs are flawed.
- **Parametrize**: Keep paths and variables in `config.yaml`, not in the rules.

---

## Maintainer Guidelines: Publishing to Zenodo

When cutting a new release, maintainers should deposit the updated version of the pipeline to Zenodo to mint a persistent DOI.

### Option A: Direct Zenodo CLI Tool
The repository includes a helper script (`rules/scripts/zenodo_deposit.py`) to build a clean software release and draft a Zenodo deposition.

1. **Generate a Zenodo Access Token:**
   * For testing: [Zenodo Sandbox](https://sandbox.zenodo.org/account/settings/applications/)
   * For production: [Zenodo Production](https://zenodo.org/account/settings/applications/)
   * *Ensure your token has `deposit:write` and `deposit:actions` scopes.*

2. **Run the Deposition CLI:**
```bash
# Upload a draft to Zenodo Sandbox (Safe test):
export ZENODO_TOKEN="your_sandbox_token_here"
python3 rules/scripts/zenodo_deposit.py

# Upload a draft to Production Zenodo:
export ZENODO_TOKEN="your_production_token_here"
python3 rules/scripts/zenodo_deposit.py --production
```
*Note: The script automatically parses name, title, version, keywords, abstract, and licensing directly from `CITATION.cff`.*

### Option B: Native GitHub-Zenodo Integration (Automated)
For public repositories hosted on GitHub:
1. Log in to Zenodo using GitHub credentials.
2. Go to the Zenodo Profile -> GitHub settings and toggle the switch for `BDB-Genomics/atacseq-pipeline` to **On**.
3. Create a new GitHub Release on the repository.
4. Zenodo will automatically capture the repository release archive and mint a new DOI.

---

*Thank you for helping us build better science.*
