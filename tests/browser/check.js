// Reads the chosen modules and shows the reports of globalThis.extismPythonCheck.
const reports = {};
for (const [id, version] of [["v041", "0.4.1"], ["v042", "0.4.2"]]) {
  document.getElementById(id).addEventListener("change", async (event) => {
    const bytes = new Uint8Array(await event.target.files[0].arrayBuffer());
    reports[version] = JSON.parse(globalThis.extismPythonCheck(version, bytes));
    document.getElementById("result").textContent = JSON.stringify(
      { userAgent: navigator.userAgent, reports }, null, 2);
  });
}
