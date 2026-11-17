document.addEventListener('DOMContentLoaded', () => {
  // Keep the repository's original relative Markdown links working after Jekyll renders them as HTML.
  if (document.body.classList.contains('guide-page')) {
    document.querySelectorAll('.prose a[href*=".md"]').forEach(link => {
      if (link.host !== location.host || !/\.md(#|$)/.test(link.href)) return;
      // README.md is the guide's overview, published at /guide/.
      link.href = /\/README\.md(#.*)?$/.test(link.href)
        ? link.href.replace(/README\.md(#.*)?$/, 'guide/$1')
        : link.href.replace(/\.md(#.*)?$/, '.html$1');
    });
  }
});
