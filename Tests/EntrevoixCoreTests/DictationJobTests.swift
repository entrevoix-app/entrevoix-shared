import Foundation
import Testing
@testable import EntrevoixCore

@Test func claimIsIdempotentAndCompletedJobsAreNotReprocessed() {
    let now = Date(timeIntervalSince1970: 100)
    var job = DictationJob(targetWorkerID: "mac-1", kind: .transcribe, options: .init(), createdAt: now)
    let firstClaim = job.claim(workerID: "mac-1", now: now)
    #expect(firstClaim)
    let secondClaim = job.claim(workerID: "mac-1", now: now)
    #expect(!secondClaim)
    job.complete(transcript: "bonjour", now: now.addingTimeInterval(1))
    let completedClaim = job.claim(workerID: "mac-1", now: now.addingTimeInterval(2))
    #expect(!completedClaim)
    #expect(job.status == .completed)
}

@Test func expiredLeaseCanBeRecovered() {
    let now = Date(timeIntervalSince1970: 100)
    var job = DictationJob(targetWorkerID: "mac-1", kind: .transcribe, options: .init(), createdAt: now)
    let firstClaim = job.claim(workerID: "mac-1", now: now, lease: 1)
    #expect(firstClaim)
    let recoveredClaim = job.claim(workerID: "mac-1", now: now.addingTimeInterval(2))
    #expect(recoveredClaim)
    #expect(job.attemptCount == 2)
}

@Test func promptRulesNormalizeAndRejectDuplicates() {
    let first = SyncedPrompt(name: " E-mail ", systemImageName: "envelope", instructions: "Fix punctuation")
    let result = PromptRules.validate(first, against: [])
    #expect((try? result.get())?.name == "E-mail")
    let duplicate = SyncedPrompt(name: " E-mail ", systemImageName: "envelope", instructions: "Other")
    #expect(PromptRules.validate(duplicate, against: [first]) == .failure(.duplicateName))
}
