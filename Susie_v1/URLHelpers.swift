import Foundation

func cleanURLParams(_ urlString: String?) -> String? {
    guard let urlString = urlString, var components = URLComponents(string: urlString) else {
        return urlString
    }
    components.query = nil
    components.fragment = nil
    return components.url?.absoluteString ?? urlString
}
