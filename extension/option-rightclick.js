// On every site: ⌥ Option + right-click opens Chrome's own menu even where the site blocks
// right-clicking (YouPic, for one), so "Save to Tearsheet" is there. Registered on the
// window before the page's own scripts run, it stops the page from seeing that right-click. A
// plain right-click is left alone, so sites with their own right-click menus keep them.
window.addEventListener("contextmenu", (e) => {
  if (!e.altKey) return;
  window.__tearsheetContextTarget = e.target;   // page-context.js won't see this click
  window.__tearsheetContextPoint = [e.clientX, e.clientY];
  e.stopImmediatePropagation();
}, true);
