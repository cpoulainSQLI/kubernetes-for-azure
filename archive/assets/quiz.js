// Shared quiz component. Markup:
// <div class="quiz"><div class="q" data-answer="b"><p class="prompt">...</p>
//   <div class="options"><button data-key="a">...</button>...</div>
//   <p class="why">...</p></div></div>
// One attempt per question, immediate feedback, running score.
(function () {
  function setup(quiz) {
    var qs = quiz.querySelectorAll(".q");
    var score = document.createElement("p");
    score.className = "score";
    score.setAttribute("aria-live", "polite");
    quiz.appendChild(score);
    var done = 0, right = 0;
    function update() {
      score.textContent = done === qs.length
        ? "Score: " + right + " / " + qs.length + ". Come back to this quiz in a few days without rereading the lesson."
        : done + " of " + qs.length + " answered";
    }
    qs.forEach(function (q) {
      var answer = q.getAttribute("data-answer");
      var buttons = q.querySelectorAll("button");
      var why = q.querySelector(".why");
      buttons.forEach(function (b) {
        b.addEventListener("click", function () {
          var ok = b.getAttribute("data-key") === answer;
          buttons.forEach(function (x) {
            x.disabled = true;
            if (x.getAttribute("data-key") === answer) x.classList.add("right");
          });
          if (!ok) b.classList.add("wrong");
          var v = document.createElement("span");
          v.className = "verdict";
          v.textContent = ok ? "Right. " : "Not this one. ";
          why.insertBefore(v, why.firstChild);
          q.classList.add("answered");
          done++; if (ok) right++;
          update();
        });
      });
    });
    update();
  }
  document.querySelectorAll(".quiz").forEach(setup);
})();
