document.addEventListener('DOMContentLoaded', () => {
  // Keep the repository's original relative Markdown links working after Jekyll renders them as HTML.
  if (document.body.classList.contains('guide-page')) {
    document.querySelectorAll('.prose a[href$=".md"]').forEach(link => {
      link.href = link.href.replace(/\.md(#.*)?$/, '.html$1');
    });
  }
});
