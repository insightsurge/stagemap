# Security policy

## Supported versions

Until stagemap is on CRAN, only the development version on `main` gets fixes. After that, the latest CRAN release
does.

## Reporting a vulnerability

Please don't open a public issue. Use GitHub's private reporting instead: on the
[Security tab](https://github.com/insightsurge/stagemap/security), choose **Report a vulnerability**. If you can't,
email analyticswithharsh@gmail.com with "stagemap security" in the subject.

stagemap draws in the browser with its bundled JavaScript (`inst/`) and makes no network requests, so the likely
problems are in that code or in how map data is turned into HTML. Include your stagemap version
(`packageVersion("stagemap")`) and a small example with synthetic data.

## What happens next

You'll get an acknowledgement. A confirmed problem is fixed in a new release, described in `NEWS.md`, with credit
if you want it. Please keep the details private until then.
