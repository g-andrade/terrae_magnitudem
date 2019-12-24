window.onload = function () {
    setupConnection();
    scheduleStatsRefresh(1000);
}

function setupConnection() {
    let socket_protocol = (window.location.protocol == "https:" ? "wss:" : "ws:")
    let socket_endpoint = window.location.hostname + (window.location.port == "" ? "" : ":" + window.location.port);
    let socket_url = `${socket_protocol}\/\/${socket_endpoint}/api/v1/measurement-socket`
    let socket = new WebSocket(socket_url)
    
    socket.onopen = function(e) {
        console.info("Connection established")
    };

    socket.onclose = function(event) {
        if (event.wasClean) {
            console.info(`Connection closed cleanly, code=${event.code} reason=${event.reason}`)
        } 
        else {
            console.error(`Connection died, code=${event.code}, reason=${event.reason}`)
        }
    };
}

function scheduleStatsRefresh(delay) {
    setTimeout(refreshStats, delay);
}

function refreshStats() {
    let endpoint = window.location.hostname + (window.location.port == "" ? "" : ":" + window.location.port);
    let url = `${window.location.protocol}\/\/${endpoint}/api/v1/measurement-stats`
    let xhr = new XMLHttpRequest();
    xhr.open("GET", url, true);
    xhr.setRequestHeader("Content-Type", "application/json");
    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4 && xhr.status === 200) {
            let stats = JSON.parse(xhr.responseText);
            updateVisualStats(stats);
            scheduleStatsRefresh(5000)
        }
    };
    xhr.send();
}

function updateVisualStats(stats) {
    document.querySelector("#estimate").innerHTML = computeSize(stats.mean);
}

function computeSize(angles_per_second) {
    let speed_of_light = 3e8;
    let speculated_factor = 0.8;
    let speculated_speed = speed_of_light * speculated_factor;
    let perimeters_per_second = angles_per_second / (2 * Math.PI);
    let perimeter_duration = 1.0 / perimeters_per_second;
    let perimeter_in_meters = perimeter_duration * speculated_speed;
    let diameter_in_meters = perimeter_in_meters / Math.PI;
    let diameter_in_km = Math.round(diameter_in_meters / 1000.0);
    return `${numberWithCommas(diameter_in_km)} km`;
}

// https://stackoverflow.com/questions/2901102/how-to-print-a-number-with-commas-as-thousands-separators-in-javascript
function numberWithCommas(x) {
    return x.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}
