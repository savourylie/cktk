# Explaining Clearly

Full rules for Phase 4 of the `clarify` skill. Each rule states the failure, then shows the fix.

Aim for **simple structure + precise meaning**. Do not dumb down technical material, and never sacrifice technical accuracy merely to improve a readability score.

---

## 1. Make scope explicit

Always make the scope clear when the statement could apply at multiple levels.

Distinguish between:

- this function vs. the module
- this API endpoint vs. the service
- this component vs. the whole system
- this ticket vs. the whole feature
- this request vs. all requests
- this implementation vs. the architecture in general
- one stage of a pipeline vs. the entire pipeline
- current behavior vs. proposed behavior
- something that *can* happen vs. something that *always* happens

Prefer explicit statements:

> Here I'm talking only about the validation performed by the upload endpoint, not validation across the whole ingestion system.

> This ticket changes how new documents are indexed. It does not change retrieval.

When useful, describe scope as **project → feature → component → operation**:

> In TaiwanEval → benchmark publishing → result ingestion → schema validation, this change only affects the final validation step.

Do not make the user infer which level you mean.

---

## 2. Resolve references explicitly

Do not use a vague reference when multiple targets are possible.

Watch for: *this, that, it, they, the system, the service, the model, the layer, the pipeline, the process, the component, the handler, the evaluator, the runtime.*

Replace them with the concrete referent.

**Bad**

> This gets passed into it before validation.

**Better**

> The API handler passes the uploaded benchmark record to `validateSubmission()` before writing it to the database.

Do not refer to something as "the X" unless X has already been introduced, or is clearly established in the retrieved project context.

---

## 3. Do not introduce unexplained abbreviations

Never assume a technical abbreviation is obvious simply because engineers commonly use it.

An abbreviation may be used directly only if:

1. the user already used it;
2. it was defined earlier in the conversation;
3. it was clearly established in the project context and is necessary to understand the current task;
4. it is extremely common general vocabulary.

Otherwise introduce it as **full term (ABBREVIATION)**:

> retrieval-augmented generation (RAG)

If the abbreviation will only be used once, do not introduce the abbreviation at all — just use the full term.

This applies to both English and Chinese explanations.

---

## 4. Introduce project terminology before relying on it

Project-specific names can be just as confusing as acronyms. Do not assume the user knows terms like these merely because they appear in a ticket or in the codebase:

*evaluator · ingestion pipeline · canonical record · resolver · orchestration layer · scoring worker · publication state*

Anchor the term when you first use it:

> The ticket calls the job that calculates benchmark scores the **scoring worker**. That's the component I'm referring to here.

Prefer terminology already used by the user, the ticket, or authoritative project documentation. Do not invent new names unnecessarily.

---

## 5. Fill in missing reasoning steps

Coding agents compress several steps because they have already inspected the implementation. The user has not reconstructed those steps.

If the reasoning is A → B → C → D, and B or C is required to understand why D follows, state them.

Especially unpack sentences containing: *therefore · this means · that's why · as a result · essentially · under the hood · by design · this allows · this prevents · this ensures.*

**Bad**

> We need to move this check earlier because otherwise the state can become inconsistent.

**Better**

> Right now the record is written to Firestore before this check runs.
> If the check fails, the request returns an error, but the invalid record has already been stored.
> Moving the check before the write prevents that partial state.

---

## 6. Prefer concrete explanations

Prefer **actor → action → object → consequence** over abstract, noun-heavy language.

**Bad**

> This moves responsibility toward the ingestion boundary.

**Better**

> The upload API will perform this validation before it sends the record further into the ingestion pipeline.

Use actual component, function, file, ticket, or document names when they help orient the user.

---

## 7. English readability

Do not dumb down technical material. Aim for **simple structure + precise meaning**.

- usually one main claim per sentence
- prefer shorter sentences
- avoid deeply nested clauses
- prefer familiar words when they are equally precise
- avoid unnecessary jargon
- roughly target Flesch-Kincaid Grade 9 or below when technical vocabulary permits
- treat sentences over roughly 30–35 words as candidates for rewriting

These are guidelines, not hard goals. Never sacrifice technical accuracy merely to improve a readability score.

---

## 8. Chinese readability

Do not apply English readability formulas such as Flesch-Kincaid directly to Chinese.

中文的原則：

- 使用較短的句子
- 一個句子通常只表達一個主要關係
- 避免一口氣塞入多層條件與從句
- 主詞不清楚時，把主詞寫出來
- 少用連續的「這個／它／其／該」
- 能用中文清楚表達時，不要突然改用英文術語
- 必須使用英文技術詞時，第一次出現要解釋
- 專案內部術語第一次出現時，要說明它實際指什麼
- 把「哪一層、哪個 component、哪一步」講清楚

不要說：

> 這邊把它移到前面之後，後面就不需要再處理這個問題。

應該說：

> 這裡的「前面」是指 **API 寫入 Firestore 之前**。
> 我建議先在 API handler 做 schema validation。
> 這樣不合法的資料根本不會被寫進 Firestore，所以後面的 worker 不需要再處理這類錯誤。

---

## 9. Optional structure for a non-trivial answer

**What we're talking about** — state the relevant ticket, feature, component, or document.

**Scope** — state exactly how broad the claim is.

**What I meant** — explain the original statement in plain language.

**Why** — fill in the missing causal or reasoning steps.

**Concrete example** — use the actual project implementation when it helps.

Do not include these headings mechanically when the answer is simple.

---

## 10. Final check

Before responding, verify:

- Did I retrieve relevant Linear / Notion / ticket / repository context if the explanation depends on project-specific facts?
- Is it clear which ticket, feature, or component I am talking about?
- Is the scope explicit?
- Does every important reference have an obvious target?
- Did I introduce unexplained abbreviations?
- Did I assume terminology merely because it appears in a ticket or document?
- Did I skip a reasoning step because I already knew it from the code or documentation?
- Am I distinguishing the specific implementation from the general concept?
- For Chinese, have I made subjects, scope, and relationships sufficiently explicit?

If not, revise before responding.
