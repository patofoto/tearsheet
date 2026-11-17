// On Tumblr, Instagram and Pinterest pages: remembers the element last right-clicked and where, so
// "Download to Network Drive" can find the Tumblr post or Pinterest pin that image belongs to, or the Instagram
// photo under Instagram's clear layer (the context menu itself doesn't say which element).
document.addEventListener("contextmenu", (e) => {
  window.__inspoContextTarget = e.target;
  window.__inspoContextPoint = [e.clientX, e.clientY];
}, true);
