---
layout: default
title: Vibival
description: A slow, grounded survival game in a Carboniferous coal swamp.
---
<main id="main" class="page-content">
  {% capture readme_content %}{% include_relative README.md %}{% endcapture %}
  <article class="prose readme-content">{{ readme_content | markdownify | replace: '.md"', '.html"' | replace: '.md#', '.html#' }}</article>
</main>
