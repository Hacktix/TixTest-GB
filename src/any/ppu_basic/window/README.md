# Basic Window Rendering Tests
These tests should simply draw a smiley image using both the background and the window. The 4-digit hex number after `m` in the filename determines which tilemap base address is used, while the 4-digit hex number after `d` in the filename represents which tile data addressing mode is used.

The WY register is set to 88, so the window should start rendering at the same line where the mouth of the smiley starts. WX is set to 7, so the whole scanline is covered by the window.

If the smiley is frowning (`:(`) the window is not being rendered. If the smiley is cut off just before the mouth, the incorrect tilemap was used. If the smiley has an expressionless face (`:|`) the incorrect tile data range was used. If the smiley is smiling (`:)`) the test has passed.