# MuleSoft Project Test Validation Standards

**Last Updated**: 2026-05-16  
**Applies To**: All agents working on MuleSoft Mule projects

---

## Overview

This document establishes mandatory test validation procedures that all agents must follow when working on MuleSoft projects. The goal is to ensure code quality, prevent regressions, and maintain the integrity of the integration platform.

---

## Mandatory Validation Checklist

After **ANY** of the following actions, you MUST run the complete validation procedure:

- ✅ Code generation (flows, subflows, error handlers)
- ✅ Flow modifications (adding/removing processors, changing logic)
- ✅ Configuration changes (connectors, properties, security)
- ✅ Test creation or modification
- ✅ DataWeave transformation updates
- ✅ Dependency updates (pom.xml changes)
- ✅ API specification changes (RAML, OAS)

---

## Phase 1: Build Validation

Verify the project compiles without errors:

```bash
cd ridexpress-experience-api
mvn clean compile
```

**Expected Result**: `BUILD SUCCESS` ✅

**If Failed**: 
- Analyze compilation errors
- Fix code issues immediately
- Rerun until compilation succeeds

---

## Phase 2: Test Execution

Run the complete MUnit test suite:

```bash
cd ridexpress-experience-api
mvn clean test
```

**Expected Results**:
- ✅ All 42 tests pass (0 failures, 0 errors)
- ✅ Code coverage ≥ 65.73% (baseline)
- ✅ Build status: `SUCCESS`
- ✅ Test output pattern: `Tests run: 42 - Failed: 0 - Errors: 0 - Skipped: 0`

**Key Metrics to Verify**:
```
=================================================================
                         Summary
=================================================================
  * Covered Processors: [N]
  * Total Processors:   [M]
  * Containers:         45
  * Resources:          9
=================================================================
             ** Application Coverage: [X.XX]% **
=================================================================
BUILD SUCCESS
```

---

## Phase 3: Coverage Analysis

Extract and verify coverage metrics:

```bash
# Option 1: Direct grep from Maven output
mvn clean test 2>&1 | grep "Application Coverage"

# Option 2: Check coverage report
grep -r "Application Coverage" ridexpress-experience-api/target/
```

**Coverage Baseline**: 65.73%

| Scenario | Action Required |
|----------|-----------------|
| Coverage = baseline | ✅ OK - No improvement needed |
| Coverage > baseline | ✅ EXCELLENT - Improvement detected |
| Coverage < baseline | ❌ FAIL - Investigate regression |

---

## Phase 4: Failure Analysis & Resolution

If any tests fail, do NOT mark work as complete:

### Step 1: Identify Failures
```bash
# Extract failed test names and error messages
mvn clean test 2>&1 | grep -A 5 "FAILED\|ERROR"
```

### Step 2: Analyze Root Cause

Use this decision tree:

| Error Type | Probable Cause | Resolution |
|-----------|----------------|-----------|
| `InvalidDataSourceForMimeType` | Mock payload not serialized | Wrap with `write(..., "application/json")` |
| `XML Validation Error` | Flow XML structure issue | Check namespace prefixes and element ordering |
| `NullPointerException` | Uninitialized variable or assertion | Verify mock setup and assertions |
| `org.mule.runtime.api.serialization.SerializationException` | Incompatible data type | Ensure DataWeave expressions return serializable types |
| `java.lang.NoClassDefFoundError` | Missing dependency | Check pom.xml versions and Maven resolution |
| `Connection refused` | External service mock missing | Verify mock-when processor configuration |

### Step 3: Apply Fixes

For common issues:

**Mock Serialization Issues**:
```xml
<!-- ❌ BROKEN -->
<munit-tools:payload value='#[{"key": "value"}]'/>

<!-- ✅ FIXED -->
<munit-tools:payload value='#[write({"key": "value"}, "application/json")]'/>
```

**XML Namespace Issues**:
```xml
<!-- ❌ BROKEN -->
<headers>...</headers>

<!-- ✅ FIXED -->
<http:headers>...</http:headers>
```

### Step 4: Retest

```bash
# Rerun full suite
mvn clean test

# OR rerun specific test file
mvn test -Dtest=riders-test

# OR rerun specific test case (if MUnit naming convention available)
mvn test -Dtest=riders-test#post-rides-test
```

### Step 5: Verify Success

Re-check metrics:
- ✅ 42/42 tests passing
- ✅ Coverage ≥ 65.73%
- ✅ Build: SUCCESS

---

## Phase 5: Reporting Results

In your final response/completion message, ALWAYS include:

### Success Report Format
```
✅ TEST VALIDATION PASSED

Test Summary:
- Total Tests: 42
- Passed: 42 (100%)
- Failed: 0
- Errors: 0
- Coverage: 65.73% ✅

Files Modified:
- ridexpress-experience-api/src/main/mule/[flow-name].xml
- ridexpress-experience-api/src/test/munit/[test-name]-test.xml

All changes validated and ready for deployment.
```

### Failure Report Format (If Encountered)
```
⚠️ TEST FAILURES DETECTED

Initial Failures:
- [test-name]: [error-type] - [root-cause]
- [test-name]: [error-type] - [root-cause]

Root Cause Analysis:
- [Issue 1]: [Explanation]
- [Issue 2]: [Explanation]

Fixes Applied:
- Changed X from [old] to [new]
- Updated Y configuration

Retest Results:
- Tests: 42/42 passed ✅
- Coverage: 65.73% ✅
- Build: SUCCESS ✅
```

---

## Quick Reference Commands

### One-Liner Validation (All Phases)
```bash
cd ridexpress-experience-api && mvn clean test && echo "✅ VALIDATION PASSED" || echo "❌ TESTS FAILED"
```

### Check Only Compilation
```bash
cd ridexpress-experience-api && mvn clean compile
```

### Check Only Tests (No Build)
```bash
cd ridexpress-experience-api && mvn test
```

### Test Specific File
```bash
cd ridexpress-experience-api && mvn test -Dtest=riders-test
```

### Generate Coverage Report
```bash
cd ridexpress-experience-api && mvn clean test -Dmunit.coverage.runCoverage=true
# Report: target/site/munit/coverage/
```

### Quick Coverage Check
```bash
cd ridexpress-experience-api && mvn clean test 2>&1 | tail -30
```

---

## Test File Reference

### Complete Test Inventory
| File | Count | Test Names |
|------|-------|-----------|
| `rides-test.xml` | 5 | post-rides, get-rides, post-rides-estimate, post-rides-id-feedback, get-rides-id-status |
| `users-test.xml` | 8 | post-user, get-user, put-user, delete-user, post-user-geolocation, get-user-vehicles, put-user-vehicles-id, + variants |
| `auth-test.xml` | 3 | post-auth-login, post-auth-token-refresh, post-auth-reset-password |
| `geolocations-test.xml` | 2 | get-geolocations-test, + variant |
| `support-test.xml` | 1 | post-support-tickets-test |
| `users-profile-test.xml` | 3 | Profile-related tests |
| `drivers-test.xml` | 20 | Driver management and rating tests |
| **TOTAL** | **42** | |

### Test Resource Location
```
ridexpress-experience-api/src/test/munit/
├── rides-test.xml
├── users-test.xml
├── users-profile-test.xml
├── auth-test.xml
├── geolocations-test.xml
├── support-test.xml
└── drivers-test.xml

ridexpress-experience-api/src/test/resources/
├── test-secrets.properties    (Not in repo - required at runtime)
└── [mock-response-data]
```

---

## Known Issues & Workarounds

### Issue: Tests Timeout
**Symptom**: `java.util.concurrent.TimeoutException` after 30+ seconds

**Cause**: External API mock not configured, slow test execution

**Fix**:
1. Verify mock-when processor is defined before flow invocation
2. Check processor path matches exactly: `config-ref="http-request-config-name"`
3. Increase timeout if legitimate (modify test-specific timeout)

### Issue: Coverage Dropped
**Symptom**: Coverage < 65.73%

**Cause**: New code added without corresponding test cases, or test failures skipping assertions

**Fix**:
1. Identify which flows lack coverage (check report in `target/site/munit/coverage/`)
2. Add MUnit test cases for new flows
3. Ensure all assertions execute (fix test failures first)

### Issue: "InvalidDataSourceForMimeType"
**Symptom**: `'application/json' requires a Stream Compatible content but found {...}`

**Cause**: Mock payload returns raw Java object instead of serialized JSON stream

**Fix**: Wrap payload with `write()` function
```xml
<munit-tools:payload value='#[write({...}, "application/json")]'/>
```

### Issue: XML Validation Errors
**Symptom**: `cvc-complex-type.2.4.a: Invalid content was found starting with element`

**Cause**: Incorrect XML namespace prefix or element ordering

**Fix**: Use correct namespace:
- HTTP elements: `<http:...>`
- Core elements: `<core:...>` or no prefix
- Database elements: `<db:...>`
- DataWeave: `<ee:...>`

---

## When NOT to Skip Validation

| Scenario | Can Skip? | Reason |
|----------|-----------|--------|
| Added a comment | ✅ Yes | No functional change |
| Updated documentation | ✅ Yes | Non-code change |
| Modified a flow | ❌ NO | Always test |
| Added a connector | ❌ NO | Always test |
| Changed a property | ❌ NO | Always test |
| Updated pom.xml | ❌ NO | Dependency changes affect tests |
| Modified error handler | ❌ NO | Critical path - always test |

---

## Integration with Copilot CLI

### Using `/every` for Scheduled Validation
To automatically run tests every hour during active development:

```bash
/every 1h cd ridexpress-experience-api && mvn clean test
```

### Using `/fleet` for Parallel Checks
For comprehensive validation across multiple checks:

```bash
/fleet
# This enables parallel task execution for:
# - Compilation check
# - Test execution
# - Coverage analysis
# - Best practices lint (if available)
```

### Creating a Validation Skill
Use the skill system to create reusable validation workflows:

```bash
/skills apply mule-test-validator
```

---

## Support & Escalation

If validation fails consistently:

1. **Check Maven**: `mvn --version` (should be 3.6.0+)
2. **Check Java**: `java -version` (should be 17+)
3. **Check Mule**: Verify runtime in `mule-artifact.json` (should be 4.10.0+)
4. **Check Dependencies**: `mvn dependency:tree` (check for conflicts)
5. **Clean Cache**: `mvn clean install -U` (force update)
6. **Review Recent Changes**: Check what was modified that broke tests

If still failing, review:
- Git diff of recent commits
- `.github/agents/my-agent.agent.md` for instructions
- Previous checkpoint/session history for similar issues
- Test output logs in `target/test-logs/`

---

## Summary

**TL;DR - The 3-Step Validation**

1. **Run Tests**: `mvn clean test`
2. **Check Results**: All 42 pass, coverage ≥ 65.73%
3. **Report Status**: Include summary in response

**Never mark work complete without running these three steps.**
