hideTranslationHint = function() {
  document.getElementsByClassName("translation-hint")[0].style.display = "none"
}

window.onload = function() {
  document.getElementById("translation-closer").addEventListener("click", hideTranslationHint);
}
