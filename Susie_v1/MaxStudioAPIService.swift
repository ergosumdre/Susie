import Foundation

class MaxStudioAPIService {
    private let baseURL = "https://api.maxstudio.ai"
    private let session = URLSession.shared

    enum APIError: Error, LocalizedError {
        case invalidURL
        case requestFailed(Error)
        case httpError(statusCode: Int, data: Data?)
        case decodingError(Error)
        case apiKeyMissing
        case jobCreationFailed(message: String?)
        case jobStatusFailed(message: String?)
        case jobNotFound
        case pollingTimeout
        case unexpectedResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "Invalid API endpoint URL."
            case .requestFailed(let error): return "Network request failed: \(error.localizedDescription)"
            case .httpError(let statusCode, _): return "API request failed with HTTP status: \(statusCode)."
            case .decodingError(let error): return "Failed to decode API response: \(error.localizedDescription)"
            case .apiKeyMissing: return "API Key is not configured."
            case .jobCreationFailed(let message): return message ?? "Failed to create baby generation job."
            case .jobStatusFailed(let message): return message ?? "Failed to get job status."
            case .jobNotFound: return "Job not found by API."
            case .pollingTimeout: return "Polling for job status timed out."
            case .unexpectedResponse: return "Received an unexpected response format from the API."
            }
        }
    }

    func generateBabyImage(fatherImageURL: String, motherImageURL: String, gender: GenderOption, apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else { throw APIError.apiKeyMissing }
        guard let url = URL(string: "\(baseURL)/baby-generator") else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let payload = BabyGenerationRequest(
            fatherImage: cleanURLParams(fatherImageURL) ?? fatherImageURL,
            motherImage: cleanURLParams(motherImageURL) ?? motherImageURL,
            gender: gender.rawValue
        )
        request.httpBody = try JSONEncoder().encode(payload)
        request.timeoutInterval = 15 // seconds

        print("BABY_API_CLIENT: Sending POST to \(url) with payload: \(payload)")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unexpectedResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8)
            print("BABY_API_CLIENT HTTP error: \(httpResponse.statusCode), Response: \(errorBody ?? "N/A")")
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        do {
            let result = try JSONDecoder().decode(APIJobResponse.self, from: data)
            if let jobId = result.jobId {
                print("BABY_API_CLIENT: Job created successfully. JobID: \(jobId)")
                return jobId
            } else {
                let errorMessage = result.errorMessage ?? "API response missing jobId"
                print("BABY_API_CLIENT Response without jobId: \(result)")
                throw APIError.jobCreationFailed(message: errorMessage)
            }
        } catch let decodeError {
            print("BABY_API_CLIENT Decoding error: \(decodeError)")
            throw APIError.decodingError(decodeError)
        }
    }

    func getJobStatus(jobId: String, apiKey: String) async throws -> APIJobStatusResponse {
        guard !apiKey.isEmpty else { throw APIError.apiKeyMissing }
        guard let url = URL(string: "\(baseURL)/baby-generator/\(jobId)") else { throw APIError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 10 // seconds
        
        // print("BABY_API_CLIENT: Sending GET to \(url)")

        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unexpectedResponse
        }

        if httpResponse.statusCode == 404 {
            let errorBody = String(data: data, encoding: .utf8)
            print("BABY_API_CLIENT: Job \(jobId) not found by API (404). Response: \(errorBody ?? "N/A")")
            // The Python code maps this to a specific "not-found" status in its return dict.
            // We can throw a specific error or return a response with status "not-found".
            // Let's try to decode first, as the API might still return a JSON for 404.
             if let errorBody = String(data: data, encoding: .utf8), errorBody.localizedCaseInsensitiveContains("Job not found") {
                 throw APIError.jobNotFound
             }
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorBody = String(data: data, encoding: .utf8)
            print("BABY_API_CLIENT HTTP error status for \(jobId): \(httpResponse.statusCode), Response: \(errorBody ?? "N/A")")
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }

        do {
            let statusData = try JSONDecoder().decode(APIJobStatusResponse.self, from: data)
            // print("BABY_API_CLIENT: Status for job \(jobId): \(statusData)")
            return statusData
        } catch let decodeError {
            print("BABY_API_CLIENT Decoding error for job status \(jobId): \(decodeError)")
            throw APIError.decodingError(decodeError)
        }
    }

    // Combined generation and polling logic
    func generateAndPollBabyImage(fatherImageURL: String, motherImageURL: String, gender: GenderOption, apiKey: String) async throws -> String {
        let jobId = try await generateBabyImage(fatherImageURL: fatherImageURL, motherImageURL: motherImageURL, gender: gender, apiKey: apiKey)
        
        let maxPolls = 30
        let pollIntervalSeconds: UInt64 = 3 // nanoseconds for Task.sleep
        let pollingTimeoutSec = maxPolls * Int(pollIntervalSeconds)

        print("BABY_LOGIC: Starting polling for job \(jobId) (max: \(maxPolls) attempts, interval: \(pollIntervalSeconds)s, timeout: \(pollingTimeoutSec)s)...")

        for attempt in 1...maxPolls {
            print("BABY_LOGIC: Polling \(jobId), attempt \(attempt)/\(maxPolls)")
            try await Task.sleep(nanoseconds: pollIntervalSeconds * 1_000_000_000)

            do {
                let statusInfo = try await getJobStatus(jobId: jobId, apiKey: apiKey)
                
                switch statusInfo.status?.lowercased() {
                case "creating", "pending", "running":
                    print("BABY_LOGIC: Job \(jobId) status is '\(statusInfo.status ?? "")'. Continuing to poll...")
                    // Continue polling
                case "completed":
                    if let resultURL = statusInfo.result?.first {
                        print("BABY_LOGIC: Job \(jobId) completed. Result URL: \(resultURL)")
                        return resultURL
                    } else {
                        print("BABY_LOGIC: Job \(jobId) completed but 'result' array is missing or empty. Data: \(statusInfo)")
                        throw APIError.unexpectedResponse // Or a more specific error
                    }
                case "failed":
                    let errorMsg = statusInfo.error ?? statusInfo.errorMessage ?? "Unknown error"
                    print("BABY_LOGIC: Job \(jobId) failed: \(errorMsg). Data: \(statusInfo)")
                    throw APIError.jobStatusFailed(message: "Job failed: \(errorMsg)")
                case "not-found": // Explicitly handled if API returns this as status
                    print("BABY_LOGIC: Job \(jobId) reported as 'not-found' by API. Stopping polling.")
                    throw APIError.jobNotFound
                default:
                    print("BABY_LOGIC: Job \(jobId) returned unexpected status: '\(statusInfo.status ?? "unknown")'. Info: \(statusInfo). Continuing poll cautiously.")
                    // Continue polling for other unknown transient statuses
                }
            } catch APIError.jobNotFound {
                print("BABY_LOGIC: Job \(jobId) not found during polling. Stopping.")
                throw APIError.jobNotFound // Re-throw
            } catch let error {
                print("BABY_LOGIC: Polling error for job \(jobId) on attempt \(attempt): \(error.localizedDescription). Details: \(error)")
                // For some errors (like transient network issues), we might want to continue polling.
                // For others (like HTTP 401/403), we should stop.
                // For now, continue polling unless it's a critical/fatal error already handled.
                if attempt == maxPolls { // If it's the last attempt and still erroring
                    throw error // Propagate the last error
                }
            }
        }
        
        print("BABY_LOGIC: Polling Timeout: Job \(jobId) did not complete within \(pollingTimeoutSec) seconds.")
        throw APIError.pollingTimeout
    }
}
