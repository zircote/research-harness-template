# Security Policy

## Verifying Release Artifacts

Every release artifact is published with a [SLSA](https://slsa.dev/) build-provenance
attestation, generated in `.github/workflows/release.yml` with
[`actions/attest-build-provenance`](https://github.com/actions/attest-build-provenance).
The attestation is signed through Sigstore; its signer identity is this
repository's own release workflow. The release pipeline re-verifies the
attestation before publishing, so a tag never publishes an unverified artifact.

To verify a downloaded release artifact yourself:

```sh
gh attestation verify research-harness-template-<version>.tar.gz \
  --repo zircote/research-harness-template
```

`--repo` alone is the correct policy here: the certificate identity is this
repository's release workflow, not a central signer, so no `--signer-workflow`
is required. A non-zero exit status means verification failed — do not trust the
artifact.

## Reporting a Vulnerability

Report security issues privately via
[GitHub Security Advisories](https://github.com/zircote/research-harness-template/security/advisories/new).
Please do not open a public issue for an undisclosed vulnerability.
