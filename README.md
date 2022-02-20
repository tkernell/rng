# Tellor Random Number Generator
The Tellor RNG is a pseudorandom number generator.

It works as follows:
1. A user requests a random number, sending two token payments, a seed reward and an oracle reward. The user receives a unique queryId which will be used to retrieve the random number from tellor. A seed value is generated from the most recent block hash.
2. During a period of time, anyone can submit a bytes32 value which gets hashed with the previous seed to generate a new seed. The last address to submit a value gets the seed reward.
3. After the seed period ends, tellor reporters hash the seed a large number of times and submit the final hash to tellor as the random number.
4. The user waits for a period of time to allow a bad value to be disputed.
5. Finally, the user retrieves their random number from tellor.
