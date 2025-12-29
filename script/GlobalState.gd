extends Node

# Track if returning from computer scene
var returning_from_computer = false

# Track if computer was infected
var computer_infected = false

# Track if player has opened computer before
var has_opened_computer_before = false

# Function to reset game state (useful for testing)
func reset_game():
	returning_from_computer = false
	computer_infected = false
	has_opened_computer_before = false
	print("Game state reset!")