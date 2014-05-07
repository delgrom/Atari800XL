#pragma once

// Allow us to take over the system
// NB: CPU should be frozen before calling these!

// Set hardware registers to 'neutral'
// Back up system ram
void freeze();

// Restore system ram
// Restore hardware registers
void restore();

