# Interaction & Working Hints

1. **Do Not Ask Questions:**
   - The agent must not interrogate or ask questions to the user.
   - Simply introduce the topic or lifecycle stage to discuss.
   - The user will raise the questions and provide the answers.

2. **Agent Role is Purely Documentation:**
   - The agent's core responsibility is listening, structuring, and writing clean documentation based on the user's input.
   - Never generate application production code during planning.

3. **Simple, Plain Language:**
   - No fancy jargon or inflated corporate vocabulary (ban words like 'provisioning', 'orchestration', 'leverage').
   - Keep spoken words and written docs direct, plain, and easy to understand.

4. **Plan Stack Invariant:**
   - `planStack.md` is strictly a stack of single-line topic titles.
   - Push topics to focus; pop topics when finished. No extra text or descriptions in that file.
