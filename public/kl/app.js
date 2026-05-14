const form = document.getElementById("query-form");
const input = document.getElementById("player-tag");
const button = document.getElementById("query-button");
const statusText = document.getElementById("status-text");
const loadingCard = document.getElementById("loading-card");
const resultCard = document.getElementById("result-card");

const playerName = document.getElementById("player-name");
const playerTagDisplay = document.getElementById("player-tag-display");
const experienceLevel = document.getElementById("experience-level");
const oldKingLevel = document.getElementById("old-king-level");
const collectionLevel = document.getElementById("collection-level");
const newKingLevel = document.getElementById("new-king-level");
const ownedCardCount = document.getElementById("owned-card-count");
const ownedSupportCount = document.getElementById("owned-support-count");
const rewardGems = document.getElementById("reward-gems");
const rewardBoxes = document.getElementById("reward-boxes");
const rewardBanners = document.getElementById("reward-banners");
const rewardTowerSkins = document.getElementById("reward-tower-skins");

form.addEventListener("submit", async (event) => {
  event.preventDefault();

  const tag = verifyTag(input.value);
  if (!tag) {
    setStatus("请输入有效的玩家 Tag。仅支持皇室战争合法字符。", true);
    input.focus();
    return;
  }

  setLoading(true);
  setStatus("", false);
  resultCard.classList.add("hidden");

  try {
    const response = await fetch(`http://api.madn.xyz/kl/api/v1/kinglevel?tag=${encodeURIComponent(tag)}`);
    const data = await response.json();

    if (!response.ok) {
      throw new Error(data.error || "查询失败，请稍后再试。");
    }

    fillResult(data);
    resultCard.classList.remove("hidden");
    setStatus("查询成功。", false);
  } catch (error) {
    setStatus(error.message || "查询失败，请稍后再试。", true);
  } finally {
    setLoading(false);
  }
});

function normalizeTag(value) {
  return value.trim().replace(/^#/, "").toUpperCase();
}

function verifyTag(tag) {
  const tagCharacters = "0289PYLQGRJCUV";
  if (!tag) return false;

  tag = tag.trim().toUpperCase().replace("#", "").replace(/O/g, "0");
  if (!tag) return false;

  for (let i = 0; i < tag.length; i += 1) {
    if (!tagCharacters.includes(tag[i])) return false;
  }

  return tag;
}

function setLoading(loading) {
  button.disabled = loading;
  button.textContent = loading ? "查询中..." : "开始查询";
  loadingCard.classList.toggle("hidden", !loading);
}

function setStatus(message, isError) {
  statusText.textContent = message;
  statusText.style.color = isError ? "#b42318" : "";
}

function fillResult(data) {
  playerName.textContent = data.playerName || "未知玩家";
  playerTagDisplay.textContent = data.playerTag || "#";
  experienceLevel.textContent = formatNumber(data.experienceLevel);
  oldKingLevel.textContent = formatNumber(data.oldKingTowerLevel);
  collectionLevel.textContent = formatNumber(data.collectionLevel);
  newKingLevel.textContent = formatNumber(data.newKingTowerLevel);
  ownedCardCount.textContent = formatNumber(data.ownedCardCount);
  ownedSupportCount.textContent = formatNumber(data.ownedTowerTroopCount);
  rewardGems.textContent = formatNumber(data.reward?.gems || 0);
  rewardBoxes.textContent = formatNumber(data.reward?.fiveStarSurpriseBoxes || 0);
  rewardBanners.textContent = formatNumber(data.reward?.banners || 0);
  rewardTowerSkins.textContent = formatNumber(data.reward?.towerSkins || 0);
}

function formatNumber(value) {
  return new Intl.NumberFormat("zh-CN").format(Number(value || 0));
}
