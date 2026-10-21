# The Pioneer Design — Website

A self-contained static version of **The Pioneer Design** interior design website
(originally at https://thepioneerdesign.com/), with working About and Projects pages.

## Pages

| File | Page |
| --- | --- |
| `index.html` | Home — full one-page site (hero, galleries, quote band, contact form, footer) |
| `about.html` | About — studio intro, services, process, contact call-to-action |
| `projects.html` | Projects — masonry portfolio of 42 project images with lightbox |
| `404.html` | Not found page used by GitHub Pages |

## Viewing it

There is no build step and no dependencies.

- **Simplest:** double-click `index.html`.
- **Local server:** run `_src\serve.ps1` (PowerShell) and open <http://localhost:8123/>.

Fonts are embedded in `assets/css/fonts.css` as data URIs, so the site renders
identically when opened straight from disk.

## Structure

```
index.html, about.html, projects.html, 404.html
assets/
  css/    original theme stylesheets, fonts.css (embedded webfonts), site.css, pages.css
  js/     main.js — mobile menu, image lightbox, contact form demo
  img/    all images used by the pages
_src/     build/generation scripts and reference copies of the original live HTML
```

## Behaviour notes

- The mobile menu, image lightbox and page navigation are implemented in vanilla
  JavaScript (`assets/js/main.js`); no WordPress or tracking scripts are loaded.
- The contact form has no backend. Submitting it locally shows the site's own
  "Thank you" panel instead of posting the message.
- The header is a three-column layout on wide screens: logo left, menu centred,
  contact right. Below 900 px it falls back to the theme's original header.

## Rebuilding the About / Projects pages

`_src/build-pages.ps1` regenerates `about.html` and `projects.html` from the header,
footer and stylesheet stack of `index.html`. Edit the content in that script (or edit
the generated HTML directly).

## Rights

All copy, photography and branding belong to The Pioneer Design. This repository is a
private working copy of the site for its owner.
