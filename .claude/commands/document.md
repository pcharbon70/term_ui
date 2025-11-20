# Create Documentation Command

## Purpose

Create new documentation or comprehensively document existing features using
industry-standard methodologies and specialized documentation agents.

## When to Use

- **New feature** needs documentation
- **Existing feature** lacks documentation
- **API endpoints** need reference documentation
- **Architecture decisions** need recording
- **User guides** need creation
- **Developer onboarding** documentation needed

## Process

### Step 1: Identify Documentation Needs

1. **Analyze target**:

   - What needs to be documented?
   - Who is the target audience?
   - What type of documentation is needed?
   - What level of detail is required?

2. **Choose documentation type**:
   - API Reference (OpenAPI/REST/GraphQL)
   - Architecture Documentation (C4 Model, ADRs)
   - User Guides (tutorials, how-tos)
   - Developer Documentation (setup, contributing)
   - Troubleshooting Guides

### Step 2: Documentation Creation

Use **documentation-expert** to:

- Select appropriate methodology (Docs as Code, DITA, minimalism)
- Apply relevant style guide (Google, Microsoft)
- Structure content with progressive disclosure
- Include necessary sections and examples
- Ensure accessibility compliance (WCAG)

### Step 3: Content Development

The documentation-expert will:

1. **Create structure** based on documentation type
2. **Write content** following methodology
3. **Add examples** and code samples
4. **Include visuals** where helpful
5. **Implement navigation** and search features

### Step 4: Quality Assurance

Use **documentation-reviewer** to:

- Validate technical accuracy
- Check completeness
- Verify style guide compliance
- Test readability scores
- Ensure accessibility standards

### Step 5: Integration

- Place documentation in appropriate location
- Update navigation and indexes
- Add to documentation build process
- Create necessary cross-references
- Commit with descriptive message

## Documentation Templates

### **Feature Documentation**

```markdown
# Feature Name

## Overview

Brief description and value proposition

## Getting Started

Minimal steps to first success

## Core Concepts

Key terms and ideas explained

## Usage Guide

### Basic Usage

Common scenarios with examples

### Advanced Usage

Complex scenarios and edge cases

## API Reference

Detailed parameter documentation

## Configuration

Available options and defaults

## Troubleshooting

Common issues and solutions

## Related Resources

Links to relevant documentation
```

### **API Documentation**

````markdown
# API Name

## Overview

API purpose and capabilities

## Authentication

How to authenticate requests

## Base URL

`https://api.example.com/v1`

## Endpoints

### GET /resource

Brief description

**Parameters**

- `param1` (required): Description
- `param2` (optional): Description

**Response**

```json
{
  "field": "value"
}
```
````

**Error Codes**

- `400`: Bad Request
- `401`: Unauthorized
- `404`: Not Found

## Rate Limiting

Request limits and headers

## Examples

Complete request/response examples

````

### **Architecture Documentation**
```markdown
# System Architecture

## Overview
High-level system description

## System Context (C4 Level 1)
External systems and users

## Container Diagram (C4 Level 2)
Applications and data stores

## Key Decisions
### ADR-001: [Decision Title]
**Status**: Accepted
**Context**: Why this decision was needed
**Decision**: What was decided
**Consequences**: Impact of decision

## Security Architecture
Authentication and authorization

## Deployment Architecture
Infrastructure and deployment

## Performance Considerations
Scalability and optimization
````

## Documentation Standards

### **Language Guidelines**

- Active voice
- Present tense
- Second person (you)
- Plain language
- Define technical terms

### **Structure Guidelines**

- Clear heading hierarchy
- Short paragraphs
- Bulleted lists
- Code examples
- Visual aids

### **Quality Metrics**

- Reading level: 8th-10th grade
- Completeness: All features covered
- Accuracy: Technically correct
- Accessibility: WCAG compliant
- Maintainability: Easy to update

## Example Usage

```bash
# Document a new API
/document api authentication-service

# Document existing feature
/document feature user-management

# Create architecture documentation
/document architecture system-overview

# Create user guide
/document guide getting-started
```

## Integration Points

- Use after feature implementation
- Include in definition of done
- Part of release process
- Regular documentation reviews
- Continuous improvement cycle

This command ensures comprehensive, high-quality documentation creation
following industry best practices and methodologies.
