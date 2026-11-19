const serverUrlInput = document.getElementById("serverUrl");
const apiKeyInput = document.getElementById("apiKey");
const webhookUrlInput = document.getElementById("webhookUrl");
const saveBtn = document.getElementById("save");
const status = document.getElementById("status");

// Load saved settings
chrome.storage.local.get(["serverUrl", "apiKey", "webhookUrl"], (data) => {
  if (data.serverUrl) serverUrlInput.value = data.serverUrl;
  if (data.apiKey) apiKeyInput.value = data.apiKey;
  if (data.webhookUrl) webhookUrlInput.value = data.webhookUrl;
});

// Save settings
saveBtn.addEventListener("click", () => {
  const serverUrl = serverUrlInput.value.trim().replace(/\/$/, ""); // strip trailing slash
  const apiKey = apiKeyInput.value.trim();

  const webhookUrl = webhookUrlInput.value.trim();   // optional

  if (!serverUrl || !apiKey) {
    status.style.color = "red";
    status.textContent = "The saver address and API key are required.";
    return;
  }
  if (webhookUrl && !/^https?:\/\//.test(webhookUrl)) {
    status.style.color = "red";
    status.textContent = "The library scan address must start with http:// or https://";
    return;
  }

  chrome.storage.local.set({ serverUrl, apiKey, webhookUrl }, () => {
    status.style.color = "green";
    status.textContent = "Settings saved!";
    setTimeout(() => (status.textContent = ""), 2000);
  });
});
