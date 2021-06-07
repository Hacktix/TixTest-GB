# Basic PPU Tests
The test ROMs in this folder are intended to test basic PPU functionality such as Background, Window and Sprite Rendering.

## bg_m9X00_d8X00 Tests
These tests should simply draw a smiley image using the background and nothing more. The 4-digit hex number after `m` in the filename determines which tilemap base address is used, while the 4-digit hex number after `d` in the filename represents which tile data addressing mode is used.

If the smiley is frowning (`:(`) the incorrect tilemap was used. If the smiley has an expressionless face (`:|`) the incorrect tile data range was used. If the smiley is smiling (`:)`) the test has passed.