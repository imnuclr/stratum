import QtQuick
import qs.theme
import qs.utils

/*
 * One of the stroke icons, redrawn as an evenly dotted line.
 *
 * The icon's path is followed and a dot set down at a fixed spacing along every
 * line and curve in it, so a cloud is a cloud's outline traced in dots, one dot
 * wide, the way the dot-matrix numerals are made. Sampling the icon on a grid
 * instead gave lines two dots thick in places and broken in others.
 */
Canvas {
    id: root

    property string name: ""
    // The standard dot, set a little closer than elsewhere so curves still read.
    property real dotPx: Theme.dot
    property real pitchPx: Theme.dot * 1.6
    property color color: Theme.fg

    implicitWidth: 64
    implicitHeight: 64

    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPitchPxChanged: requestPaint()

    // The path as polylines in icon units: arcs and curves broken into short
    // straight pieces, each subpath its own list of points.
    function flatten(d) {
        const tokens = d.match(/[a-zA-Z]|-?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?/g) ?? [];
        const lines = [];
        let line = null;
        let i = 0;
        let cmd = "";
        let x = 0, y = 0, sx = 0, sy = 0;
        const num = () => parseFloat(tokens[i++]);
        const isNum = () => i < tokens.length && !/^[a-zA-Z]$/.test(tokens[i]);
        const to = (nx, ny) => {
            if (!line) {
                line = [[x, y]];
                lines.push(line);
            }
            line.push([nx, ny]);
            x = nx;
            y = ny;
        };

        const arc = (rx, ry, phi, large, sweep, x2, y2) => {
            if (rx === 0 || ry === 0) {
                to(x2, y2);
                return;
            }
            const rad = phi * Math.PI / 180;
            const cos = Math.cos(rad), sin = Math.sin(rad);
            const dx = (x - x2) / 2, dy = (y - y2) / 2;
            const x1p = cos * dx + sin * dy, y1p = -sin * dx + cos * dy;
            rx = Math.abs(rx);
            ry = Math.abs(ry);
            const lam = (x1p * x1p) / (rx * rx) + (y1p * y1p) / (ry * ry);
            if (lam > 1) {
                rx *= Math.sqrt(lam);
                ry *= Math.sqrt(lam);
            }
            const num2 = rx * rx * ry * ry - rx * rx * y1p * y1p - ry * ry * x1p * x1p;
            const den = rx * rx * y1p * y1p + ry * ry * x1p * x1p;
            let coef = Math.sqrt(Math.max(0, num2 / den));
            if (large === sweep)
                coef = -coef;
            const cxp = coef * rx * y1p / ry, cyp = -coef * ry * x1p / rx;
            const cx = cos * cxp - sin * cyp + (x + x2) / 2;
            const cy = sin * cxp + cos * cyp + (y + y2) / 2;
            const ang = (ux, uy, vx, vy) => {
                const a = Math.atan2(ux * vy - uy * vx, ux * vx + uy * vy);
                return a;
            };
            const t1 = ang(1, 0, (x1p - cxp) / rx, (y1p - cyp) / ry);
            let dt = ang((x1p - cxp) / rx, (y1p - cyp) / ry, (-x1p - cxp) / rx, (-y1p - cyp) / ry);
            if (!sweep && dt > 0)
                dt -= 2 * Math.PI;
            else if (sweep && dt < 0)
                dt += 2 * Math.PI;
            const steps = Math.max(6, Math.ceil(Math.abs(dt) * Math.max(rx, ry) / 0.4));
            for (let k = 1; k <= steps; k++) {
                const t = t1 + dt * k / steps;
                to(cos * rx * Math.cos(t) - sin * ry * Math.sin(t) + cx,
                   sin * rx * Math.cos(t) + cos * ry * Math.sin(t) + cy);
            }
        };

        const cubic = (x1, y1, x2, y2, x3, y3) => {
            const x0 = x, y0 = y;
            for (let k = 1; k <= 16; k++) {
                const t = k / 16, u = 1 - t;
                to(u * u * u * x0 + 3 * u * u * t * x1 + 3 * u * t * t * x2 + t * t * t * x3,
                   u * u * u * y0 + 3 * u * u * t * y1 + 3 * u * t * t * y2 + t * t * t * y3);
            }
        };

        while (i < tokens.length) {
            if (!isNum())
                cmd = tokens[i++];
            const rel = cmd === cmd.toLowerCase();
            const ox = rel ? x : 0, oy = rel ? y : 0;
            switch (cmd.toUpperCase()) {
            case "M": {
                const nx = num() + ox, ny = num() + oy;
                x = sx = nx;
                y = sy = ny;
                line = [[x, y]];
                lines.push(line);
                // Further pairs after a move are lines.
                cmd = rel ? "l" : "L";
                break;
            }
            case "L":
                to(num() + ox, num() + oy);
                break;
            case "H":
                to(num() + ox, y);
                break;
            case "V":
                to(x, num() + oy);
                break;
            case "A": {
                const rx = num(), ry = num(), phi = num(), large = num() !== 0, sweep = num() !== 0;
                arc(rx, ry, phi, large, sweep, num() + ox, num() + oy);
                break;
            }
            case "C": {
                const a = [num() + ox, num() + oy, num() + ox, num() + oy, num() + ox, num() + oy];
                cubic(...a);
                break;
            }
            case "Z":
                to(sx, sy);
                line = null;
                break;
            default:
                // Anything else is not used by these icons; skip its number.
                i++;
            }
        }
        return lines;
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (root.name.length === 0)
            return;
        const scale = Math.min(root.width, root.height) / 24;
        const r = root.dotPx / 2;
        const pitch = root.pitchPx / scale;
        ctx.fillStyle = root.color;
        ctx.beginPath();
        const dot = (px, py) => {
            ctx.moveTo(px * scale + r, py * scale);
            ctx.arc(px * scale, py * scale, r, 0, 2 * Math.PI);
        };
        for (const line of root.flatten(Icons.path(root.name))) {
            // Spread the dots evenly over each line's whole length, so a line
            // starts and ends on a dot whatever its length.
            let length = 0;
            for (let k = 1; k < line.length; k++)
                length += Math.hypot(line[k][0] - line[k - 1][0], line[k][1] - line[k - 1][1]);
            const n = Math.max(0, Math.round(length / pitch));
            const step = n > 0 ? length / n : 0;
            dot(line[0][0], line[0][1]);
            let next = step;
            let walked = 0;
            for (let k = 1; k < line.length && n > 0; k++) {
                const ax = line[k - 1][0], ay = line[k - 1][1];
                const seg = Math.hypot(line[k][0] - ax, line[k][1] - ay);
                while (seg > 0 && next <= walked + seg + 1e-6) {
                    const t = (next - walked) / seg;
                    dot(ax + (line[k][0] - ax) * t, ay + (line[k][1] - ay) * t);
                    next += step;
                }
                walked += seg;
            }
        }
        ctx.fill();
    }
}
