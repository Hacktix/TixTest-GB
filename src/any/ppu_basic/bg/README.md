# Basic Background Rendering Tests
These tests should simply draw a smiley image using the background and nothing more. The 4-digit hex number after `m` in the filename determines which tilemap base address is used, while the 4-digit hex number after `d` in the filename represents which tile data addressing mode is used.

If the smiley is frowning (`:(`) the incorrect tilemap was used. If the smiley has an expressionless face (`:|`) the incorrect tile data range was used. If the smiley is smiling (`:)`) the test has passed.