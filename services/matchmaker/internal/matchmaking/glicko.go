package matchmaking

import (
	"math"
)

const (
	Tau = 0.5
)

type Rating struct {
	Mu    float64 // Rating
	Phi   float64 // Rating Deviation
	Sigma float64 // Rating Volatility
}

func NewRating() Rating {
	return Rating{
		Mu:    1500.0,
		Phi:   350.0,
		Sigma: 0.06,
	}
}

func (r *Rating) Update(opponent Rating, score float64) {
	// Simplified Glicko-2 update logic for demonstration
	// In a real implementation, this would involve complex iterative calculations
	// converting to Glicko-2 scale, updating, and converting back.
	
	// Placeholder logic:
	expectedScore := 1.0 / (1.0 + math.Pow(10.0, (opponent.Mu-r.Mu)/400.0))
	kFactor := 32.0 // Simplified K-factor
	r.Mu = r.Mu + kFactor*(score-expectedScore)
	
	// Decay Phi (increase uncertainty)
	r.Phi = math.Sqrt(r.Phi*r.Phi + r.Sigma*r.Sigma)
}
