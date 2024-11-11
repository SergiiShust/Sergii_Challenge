package main

import (
	"bufio"
	"fmt"
	"os"
	"regexp"
	"strconv"
	"strings"
)

// validateCreditCard checks if a credit card number is valid.
func validateCreditCard(card string) bool {
	// Remove any leading/trailing whitespace
	card = strings.TrimSpace(card)

	// Check if card starts with 4, 5, or 6 and matches other requirements
	// 1. Contains exactly 16 digits or 16 digits with hyphens in groups of 4
	// 2. Does not contain 4 or more consecutive repeated digits
	cardPattern := regexp.MustCompile(`^(4|5|6)\d{15}$|^(4|5|6)\d{3}-\d{4}-\d{4}-\d{4}$`)
	if !cardPattern.MatchString(card) {
		return false
	}

	// Remove hyphens to check for consecutive repeating digits
	cardClean := strings.ReplaceAll(card, "-", "")

	// Manually check for 4 or more consecutive repeating digits
	for i := 0; i <= len(cardClean)-4; i++ {
		if cardClean[i] == cardClean[i+1] && cardClean[i] == cardClean[i+2] && cardClean[i] == cardClean[i+3] {
			return false
		}
	}

	return true
}

func main() {
	scanner := bufio.NewScanner(os.Stdin)

	// Prompt and read the number of credit cards to validate
	fmt.Print("Enter number of credit cards to validate: ")
	scanner.Scan()
	numCardsStr := scanner.Text()
	numCards, err := strconv.Atoi(numCardsStr)
	if err != nil || numCards <= 0 {
		fmt.Println("Invalid input for number of credit cards. Please enter a positive integer.")
		return
	}

	// Slice to hold validation results
	results := make([]string, numCards)
	for i := 0; i < numCards; i++ {
		fmt.Printf("Enter card number %d: ", i+1)
		scanner.Scan()
		card := scanner.Text()

		if validateCreditCard(card) {
			results[i] = "Valid"
		} else {
			results[i] = "Invalid"
		}
	}

	// Print results
	fmt.Println("Results:")
	for _, result := range results {
		fmt.Println(result)
	}
}
