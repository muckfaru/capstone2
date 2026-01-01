extends Node

# Track if returning from computer scene
var returning_from_computer = false

# Track if computer was infected
var computer_infected = false

# Track if player has opened computer before
var has_opened_computer_before = false

# Track if player joined CA Organization
var joined_ca_organization = false

# Track if player declined CA offer
var declined_ca_offer = false

# Track if player completed CA training mission
var ca_training_completed = false

# Function to reset game state (useful for testing)
func reset_game():
	returning_from_computer = false
	computer_infected = false
	has_opened_computer_before = false
	joined_ca_organization = false
	declined_ca_offer = false
	ca_training_completed = false
	print("Game state reset!")