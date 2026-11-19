// On Tumblr, Instagram and Pinterest pages: remembers the element last right-clicked and where, so
// "Save to Tearsheet" can find the Tumblr post or Pinterest pin that image belongs to, or the Instagram
// photo under Instagram's clear layer (the context menu itself doesn't say which element).
document.addEventListener("contextmenu", (e) => {
  window.__tearsheetContextTarget = e.target;
  window.__tearsheetContextPoint = [e.clientX, e.clientY];
}, true);
