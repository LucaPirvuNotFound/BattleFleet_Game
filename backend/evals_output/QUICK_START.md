# Quick Start: Admiral AI Evaluation

## One-Line Run
```bash
cd backend && python3 evals_output/eval_admiral.py
```

## What Gets Tested

✅ **Response Validation**
- Correct JSON structure
- Valid ship indices
- Valid action types (move/fire)

✅ **Performance Metrics**
- Latency: Time from request to response
- TTFT: Time to First Token (estimated)
- TPS: Tokens Per Second (throughput)

✅ **Decision Accuracy**
- Did it decide to shoot? (tactical decision)
- How accurate was the aim? (bearing error in degrees)
- Did it choose valid weapons?
- Distance to target vs weapon range

## Expected Results

For a working admiral AI with Ollama models cached in RAM:
- Latency: ~8-15ms
- Decision to Shoot: 70-90% of scenarios
- Bearing Error: 2-5 degrees
- Weapon Validity: 95%+

## Output Files

- `evaluation_results.json` - Full detailed results
- `README.md` - Full documentation
- `eval_admiral.py` - The evaluation script itself

## Debugging

If latency is high (>100ms):
- First call after server restart: expected (~80s for model load)
- Subsequent calls: should be <20ms
- Check if Ollama is running: `curl http://localhost:11434/api/tags`

If validation fails:
- Check response JSON format in `evaluation_results.json`
- Look for error messages in the `validation.errors` array
