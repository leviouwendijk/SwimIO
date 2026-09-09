import SwimIO

@main
enum SwimIOTest {
    static func main() throws {
        try SwimStorageSmoke.run()

        print(
            "swim io storage smoke passed"
        )
    }
}
