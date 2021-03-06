//
//  ContentView.swift
//  SwiftUITest
//
//  Created by Andy Qua on 04/06/2019.
//  Copyright © 2019 Andy Qua. All rights reserved.
//

import SwiftUI
import Combine
import NFCPassportReader

struct MyButtonStyle: ButtonStyle {
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .foregroundColor(.secondary)
    }
    
}


struct CheckBoxView: View {
    @Binding var checked: Bool
    var text : String
    
    var body: some View {
        HStack() {

            Button(action: {
                self.checked.toggle()
            }) {
                HStack(alignment: .center, spacing: 10) {

                Text(text)
                Image(systemName:self.checked ? "checkmark.square.fill" : "square")
                }
            }
            .frame(height: 44, alignment: .center)
            .padding(.trailing)
            .foregroundColor(Color.secondary)
            .background(Color(red: 0.999, green: 0.999, blue: 0.999))
            .buttonStyle(MyButtonStyle())
//            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct ClearButton: ViewModifier {
    @Binding var text: String
    
    public func body(content: Content) -> some View {
        HStack {
            content
            if ( text != "" ) {
                Button(action: {
                    self.text = ""
                }) {
                    Image(systemName: "multiply.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}


// A View that just uses the UIColor systemBackground allowing
// For light.dark mode support - willo be removed once this makes its way into SwiftUI properly
struct BackgroundView : UIViewRepresentable {
    
    var color: UIColor = .systemBackground
    
    func makeUIView(context: Context) -> UIView {
        UIView(frame: .zero)
    }
    
    func updateUIView(_ view: UIView, context: Context) {
        view.backgroundColor = color
    }
}

struct ContentView : View {
    @ObservedObject var passportDetails = PassportDetails()

    @State private var showingAlert = false
    @State private var showDetails = false
    @State private var alertTitle : String = ""
    @State private var alertMessage : String = ""
    @State private var captureLog : Bool = true
    @State private var logLevel : Int = 0
    @State var page = 0
    
    private var logLevels = ["Verbose", "Debug", "Info", "Warning", "Error"]

    private let passportReader = PassportReader()

    var body: some View {
        ZStack {

            VStack {
                Text( "Enter passport details" )
                    .foregroundColor(Color.secondary)
                    .font(.title)
                    .padding(0)

                TextField("Passport number",
                          text: $passportDetails.passportNumber)
                    .modifier(ClearButton(text: $passportDetails.passportNumber))
                    .textContentType(.name)
                    .foregroundColor(Color.primary)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding([.leading, .trailing])

                TextField("Date of birth (YYMMDD)",
                          text: $passportDetails.dateOfBirth)
                    .modifier(ClearButton(text: $passportDetails.dateOfBirth))
                    .foregroundColor(Color.primary)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding([.leading, .trailing])
                
                TextField("Passport expiry date (YYMMDD)",
                          text: $passportDetails.expiryDate)
                    .modifier(ClearButton(text: $passportDetails.expiryDate))
                    .foregroundColor(Color.primary)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding([.leading, .trailing])
                
                HStack {
                    CheckBoxView( checked: $captureLog, text: "Capture logs" )
                        .padding([.leading, .trailing])
                    Spacer()
                    Button( action: {
                        shareLogs()
                    }) {
                        Text( "Share logs" )
                            .foregroundColor(.secondary)
                    }
                    .padding([.trailing])
                }
                
                Picker(selection: $logLevel, label:Text("") ) {
                    ForEach(0 ..< logLevels.count) {
                        Text(logLevels[$0]).tag(0)
                    }
                }.pickerStyle(SegmentedPickerStyle())
                .padding([.leading, .trailing])

                Button(action: {
                    self.scanPassport()
                }) {
                    Text("Scan Passport")
                        .font(.largeTitle)
                    .foregroundColor(passportDetails.isValid ? .secondary : Color.secondary.opacity(0.25))
                    }
                    .disabled( !passportDetails.isValid )
                
                Picker(selection: $page, label: Text("View?")) {
                    Text("Passport").tag(0)
                    Text("Details").tag(1)
                }.pickerStyle(SegmentedPickerStyle())
                    .padding(.bottom,20)
                    .padding([.leading, .trailing])

                if page == 0 && showDetails {
                    PassportView(passportDetails:passportDetails)
                        .frame(width: UIScreen.main.bounds.width-20, height: 220)
                } else if page == 1 && showDetails {
                    DetailsView(passportDetails:passportDetails)
                }

                Spacer()
            }
            

        }.alert(isPresented: $showingAlert) {
                Alert(title: Text(alertTitle), message:
                    Text(alertMessage), dismissButton: .default(Text("Got it!")))
    }
     .background(BackgroundView())
    }
}

extension ContentView {
    
    func shareLogs() {
        do {
            let arr = Log.logData
            let data = try JSONSerialization.data(withJSONObject: arr, options: .prettyPrinted)
            
            let temporaryURL = URL(fileURLWithPath: NSTemporaryDirectory() + "passportreader.log")
            try data.write(to: temporaryURL)
            
            let av = UIActivityViewController(activityItems: [temporaryURL], applicationActivities: nil)
            UIApplication.shared.windows.first?.rootViewController?.present(av, animated: true, completion: nil)
        } catch {
            print( "ERROR - \(error)" )
        }

    }
    func scanPassport( ) {
        self.showDetails = false
        let mrzKey = self.passportDetails.getMRZKey()

        // Set the masterListURL on the Passport Reader to allow auto passport verification
        let masterListURL = Bundle.main.url(forResource: "masterList", withExtension: ".pem")!
        passportReader.setMasterListURL( masterListURL )

        // If we want to read only specific data groups we can using:
//        let dataGroups : [DataGroupId] = [.COM, .SOD, .DG1, .DG2, .DG7, .DG11, .DG12, .DG14, .DG15]
//        passportReader.readPassport(mrzKey: mrzKey, tags:dataGroups, completed: { (passport, error) in
        
        Log.logLevel = LogLevel(rawValue: self.logLevel) ?? .info
        if captureLog {
            Log.storeLogs = true
        }
        Log.clearStoredLogs()
        
        // This is also how you can override the default messages displayed by the NFC View Controller
        passportReader.readPassport(mrzKey: mrzKey, customDisplayMessage: { (displayMessage) in
            switch displayMessage {
                case .requestPresentPassport:
                    return "Hold your iPhone near an NFC enabled passport."
                default:
                    // Return nil for all other messages so we use the provided default
                    return nil
            }
        }, completed: { (passport, error) in
            if let passport = passport {
                // All good, we got a passport

                DispatchQueue.main.async {
                    self.passportDetails.passport = passport
                    self.showDetails = true
                }

            } else {
                self.alertTitle = "Oops"
                self.alertTitle = "\(error?.localizedDescription ?? "Unknown error")"
                self.showingAlert = true
            }
        })

    }
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {

    static var previews: some View {
//        let pptData = "P<GBRTEST<<TEST<TEST<<<<<<<<<<<<<<<<<<<<<<<<1234567891GBR8001019M2106308<<<<<<<<<<<<<<04"
        let passport = NFCPassportModel()
        let pd = PassportDetails()
        pd.passport = passport
        
        
        return Group {
            ContentView().environment( \.colorScheme, .light).environmentObject(pd)
            ContentView().environment( \.colorScheme, .dark).environmentObject(pd)
        }
    }
}
#endif


