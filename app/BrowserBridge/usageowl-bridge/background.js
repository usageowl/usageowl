// UsageOwl Bridge — fetches your claude.ai usage page data (using your own
// browser session) and posts the resulting JSON to the UsageOwl menu bar app
// on 127.0.0.1. The cookie never leaves your browser; nothing goes anywhere
// except localhost.

const ORG = 'https://claude.ai/api/organizations';
const BRIDGE = 'http://127.0.0.1:18347/claude-usage';

async function sync() {
  try {
    const orgsRes = await fetch(ORG, { credentials: 'include' });
    if (!orgsRes.ok) return;
    const orgs = await orgsRes.json();
    const org = Array.isArray(orgs) ? orgs[0] : null;
    const id = org && (org.uuid || org.id);
    if (!id) return;

    const usageRes = await fetch(`${ORG}/${id}/usage`, { credentials: 'include' });
    if (!usageRes.ok) return;
    const usage = await usageRes.json();

    await fetch(BRIDGE, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(usage),
    });
  } catch (e) {
    // UsageOwl not running, or not signed in to claude.ai — try again next visit.
  }
}

chrome.tabs.onUpdated.addListener((tabId, change, tab) => {
  if (change.status === 'complete' && tab.url && tab.url.startsWith('https://claude.ai/')) {
    sync();
  }
});

chrome.action.onClicked.addListener(() => {
  chrome.tabs.create({ url: 'https://claude.ai/settings/usage' });
});
