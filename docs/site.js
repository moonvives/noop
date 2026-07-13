const locale = "pt-BR";
const dateNode = document.querySelector("#live-date");
const timeNode = document.querySelector("#live-time");
const calendarInput = document.querySelector("#site-calendar");
const monthNode = document.querySelector("#calendar-month");
const weekNode = document.querySelector("#week-strip");

const pad = value => String(value).padStart(2, "0");
const inputDate = date => `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
const atLocalMidnight = value => {
  const [year, month, day] = value.split("-").map(Number);
  return new Date(year, month - 1, day);
};

function renderClock() {
  const now = new Date();
  dateNode.textContent = new Intl.DateTimeFormat(locale, {
    weekday: "long", day: "numeric", month: "long", year: "numeric"
  }).format(now);
  timeNode.textContent = new Intl.DateTimeFormat(locale, {
    hour: "2-digit", minute: "2-digit", hour12: false
  }).format(now);
  timeNode.dateTime = now.toISOString();
}

function startOfWeek(date) {
  const result = new Date(date);
  const mondayOffset = (result.getDay() + 6) % 7;
  result.setDate(result.getDate() - mondayOffset);
  result.setHours(0, 0, 0, 0);
  return result;
}

function renderCalendar(date) {
  monthNode.textContent = new Intl.DateTimeFormat(locale, { month: "long", year: "numeric" }).format(date);
  const first = startOfWeek(date);
  weekNode.replaceChildren();
  for (let index = 0; index < 7; index += 1) {
    const day = new Date(first);
    day.setDate(first.getDate() + index);
    const button = document.createElement("button");
    button.type = "button";
    button.className = "week-day";
    if (inputDate(day) === inputDate(date)) button.classList.add("selected");
    button.innerHTML = `<span>${new Intl.DateTimeFormat(locale, { weekday: "short" }).format(day).toUpperCase()}</span><b>${day.getDate()}</b><small>${day.getFullYear()}</small>`;
    button.setAttribute("aria-label", new Intl.DateTimeFormat(locale, {
      weekday: "long", day: "numeric", month: "long", year: "numeric"
    }).format(day));
    button.addEventListener("click", () => {
      calendarInput.value = inputDate(day);
      renderCalendar(day);
    });
    weekNode.append(button);
  }
}

const today = new Date();
calendarInput.value = inputDate(today);
calendarInput.max = inputDate(today);
calendarInput.addEventListener("change", event => {
  if (event.target.value) renderCalendar(atLocalMidnight(event.target.value));
});

renderClock();
renderCalendar(today);
window.setInterval(renderClock, 15_000);
