void drawAxes() {
    stroke(100);     
    strokeWeight(1); 
    fill(100);
    float axisLen = 360; 
    line(-axisLen, 0, axisLen, 0); 
    line(0, -axisLen, 0, axisLen); 
    float arrowSize = 6;
    pushMatrix();
    translate(axisLen, 0);
    triangle(0, 0, -arrowSize, -arrowSize/2, -arrowSize, arrowSize/2);
    popMatrix();
    pushMatrix();
    translate(-axisLen, 0);
    triangle(0, 0, arrowSize, -arrowSize/2, arrowSize, arrowSize/2);
    popMatrix();
    pushMatrix();
    translate(0, axisLen);
    triangle(0, 0, -arrowSize/2, -arrowSize, arrowSize/2, -arrowSize);
    popMatrix();
    pushMatrix();
    translate(0, -axisLen);
    triangle(0, 0, -arrowSize/2, arrowSize, arrowSize/2, arrowSize);
    popMatrix();
    pushMatrix();
    scale(1, -1); 
    textSize(14);
    fill(150);
    textAlign(CENTER, CENTER);
    text("+X", axisLen - 20, 20);      // Right
    text("-X", -axisLen + 20, 20);     // Left
    text("+Y", 20, -axisLen + 20);     // Top (Note negative Y coord)
    text("-Y", 20, axisLen - 20);      // Bottom (Note positive Y coord)
    popMatrix();
}

void drawDottedLine(float x1, float y1, float x2, float y2, float steps) {
    for (int i = 0; i <= steps; i++) {
        // lerp() calculates a point between 0.0 (start) and 1.0 (end)
        float x = lerp(x1, x2, i / steps);
        float y = lerp(y1, y2, i / steps);
        point(x, y); // Use point() for dots, or small rects/ellipses
    }
}

void dashedLine(float x1, float y1, float x2, float y2, float dashLen, float gapLen) {
    float totalDist = dist(x1, y1, x2, y2);
    float dx = (x2 - x1) / totalDist; // Unit vector X component
    float dy = (y2 - y1) / totalDist; // Unit vector Y component

    float currentDist = 0;

    while (currentDist < totalDist) {
        // 1. Calculate start of this dash
        float startX = x1 + dx * currentDist;
        float startY = y1 + dy * currentDist;

        // 2. Calculate end of this dash
        float endX = startX + dx * dashLen;
        float endY = startY + dy * dashLen;

        // 3. CLAMP: If this dash goes past the target, stop exactly at the target
        if (currentDist + dashLen > totalDist) {
            endX = x2;
            endY = y2;
        }

        line(startX, startY, endX, endY);

        // 4. Move forward by dash + gap
        currentDist += dashLen + gapLen;
    }
}

void drawPointLabel(String name, float x, float y, color c, boolean showCoords) {
    float offset = 45;
    float m = dist(0, 0, x, y);
    if (m == 0) m = 1;

    float tx = (x / m) * (m + offset);
    float ty = (y / m) * (m + offset);

    pushMatrix();
    translate(tx, ty);
    scale(1, -1);

    fill(c);
    textAlign(CENTER, CENTER);
    textSize(14);

    String label = name;
    if (showCoords) {
        label += "\n(" + nfc(x, 1) + ", " + nfc(y, 1) + ")";
    }

    text(label, 0, 0);
    popMatrix();
}

void watermarkBackground(color bgColor, color textColor, String text) {
    background(bgColor);
    
    pushMatrix();
    resetMatrix();
    
    fill(textColor);
    noStroke();
    textSize(24);
    textAlign(CENTER, CENTER);
    
    float angle = -30;
    float diagonal = sqrt(width * width + height * height);
    float spacing = 80;
    
    pushMatrix();
    translate(width / 2, height / 2);
    rotate(radians(angle));
    
    for (float y = -diagonal; y < diagonal; y += spacing) {
        for (float x = -diagonal; x < diagonal; x += textWidth(text) * 1.5) {
            pushMatrix();
            translate(x, y);
            text(text, 0, 0);
            popMatrix();
        }
    }
    popMatrix();
    
    popMatrix();
}	
