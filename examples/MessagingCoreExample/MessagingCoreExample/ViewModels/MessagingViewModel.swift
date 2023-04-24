//
//  MessagingViewModel.swift
//  MessagingCoreExample
//

import Foundation
import SMIClientCore
import SwiftUI

public class MessagingViewModel: NSObject {

    // Conversation client object
    var conversationClient: ConversationClient?
    
    // Core object
    private var coreClient: CoreClient?
    
    // Contains all the conversation entries
    @Published var observeableConversationData: ObserveableConversationEntries?

    init(observeableConversationData: ObserveableConversationEntries) {
        super.init()
        self.observeableConversationData = observeableConversationData
        
        // Turn on debug logging
        setDebugLogging()
        
        // Create a conversation client object
        createConversationClient()
    }

    // MARK: Public Functions

    /// Fetches all the conversation entries and updates the view.
    public func fetchAndUpdateConversation() {
        retrieveAllConversationEntries(completion: { messages in
            if let messages = messages {
                DispatchQueue.main.async {
                    self.observeableConversationData?.conversationEntries = []
                    for message in messages.reversed() {
                        self.observeableConversationData?.conversationEntries.append(message)
                    }
                }
            }
        })
    }

    /// Sends a message to the agent.
    public func sendTextMessage(message: String) {
        conversationClient?.send(message: message)
    }

    /// Sends an image to the agent.
    public func sendImageMessage(image: Data, fileName: String) {
        conversationClient?.send(image: image, fileName: fileName)
    }

    /// Sends a PDF file to the agent.
    public func sendPDFMessage(pdf: PDFDocument) {
        conversationClient?.send(pdf: pdf)
    }

    /// Sends a choice reply to the agent.
    public func sendChoiceReply(choice: Choice) {
        conversationClient?.send(reply: choice)
    }

    /// Resets the conversation ID and creates a new conversation.
    public func resetChat() {
        let defaults = UserDefaults.standard
        let uuid = UUID()
        defaults.set(uuid.uuidString, forKey: "convoID")
        createConversationClient()
    }

    /// An example of creating a UUID for a conversation that
    /// persists after app restart. Once the conversation is
    /// created, this UUID can be used when creating the
    /// conversation client so the conversation can be resumed.
    public func getConvoID() -> UUID {
        let defaults = UserDefaults.standard
        let uuid = UUID()
        if let convoID = defaults.string(forKey: "convoID") {
            if (convoID.isEmpty) {
                defaults.set(uuid.uuidString, forKey: "convoID")
                return uuid
            }
            return UUID(uuidString: convoID) ?? UUID()
        } else {
            defaults.set(uuid.uuidString, forKey: "convoID")
            return uuid
        }
    }

    // MARK: Private Functions

    /// Creates a conversation client object after setting up the config object.
    private func createConversationClient() {
        
        // TO DO: Replace the config file in this app (configFile.json)
        //        with the config file you downloaded from your Salesforce org.
        //        To learn more, see:
        // https://help.salesforce.com/s/articleView?id=sf.miaw_deployment_mobile.htm

        guard let configPath = Bundle.main.path(forResource: "configFile", ofType: "json") else {
            NSLog("Unable to find configFile.json file.")
            return
        }
        
        let configURL = URL(fileURLWithPath: configPath)

        // TO DO: Change the userVerificationRequired flag match the verification
        //        requirements of the endpoint.
        //        To learn more, see:
        // https://developer.salesforce.com/docs/service/messaging-in-app/guide/ios-user-verification.html
        let userVerificationRequired = false
        
        guard let config = Configuration(url: configURL,
                                         userVerificationRequired: userVerificationRequired) else {
            NSLog("Unable to create Configuration object.")
            return
        }

        // Create core client
        coreClient = CoreFactory.create(withConfig: config)

        // Start listening for events
        coreClient?.start()

        // Handle pre-chat requests with a HiddenPreChatDelegate implementation
        CoreFactory.create(withConfig: config).setPreChatDelegate(delegate: self, queue: DispatchQueue.main)

        // Handle auto-response component requests with a TemplatedUrlDelegate implementation
        CoreFactory.create(withConfig: config).setTemplatedUrlDelegate(delegate: self, queue: DispatchQueue.main)

        // Handle user verification requests with a UserVerificationDelegate implementation
        CoreFactory.create(withConfig: config).setUserVerificationDelegate(delegate: self, queue: DispatchQueue.main)

        // Handle error messages from the SDK
        CoreFactory.create(withConfig: config).addDelegate(delegate: self)

        // Create the conversation client
        conversationClient = coreClient?.conversationClient(with: getConvoID())

        // Retrieve and submit any PreChat fields
        getPreChatFieldsFromConfig(completion: { preChatFields in
            self.submitPreChatFields(preChatFields: preChatFields)
        })
    }

    /// Retrieves all conversation entries from the current conversation.
    private func retrieveAllConversationEntries(completion: @escaping ([ConversationEntry]?) -> ()) {
        conversationClient?.entries(withLimit: 0, olderThanEntry: nil, completion: { messages, _, _ in
            completion(messages)
        })
    }

    /// Retrieves pre-chat fields from the remote config.
    private func getPreChatFieldsFromConfig(completion: @escaping ([PreChatField]?) -> ()) {
        coreClient?.retrieveRemoteConfiguration(completion: { remoteConfig, error in
            if let preChatFields = remoteConfig?.preChatConfiguration?.first?.preChatFields {
                completion(preChatFields)
            }
        })
    }

    /// This is an example of how you would assign values to
    /// your pre-chat fields. You would need to create your own
    /// UI to get values from a user and then map them to the
    /// pre-chat values. You would then submit the pre-chat
    /// fields to Salesforce.
    private func submitPreChatFields(preChatFields: [PreChatField]?) {
        guard let preChatFields = preChatFields else { return }

        for preChatField in preChatFields {
            if preChatField.isRequired {
                preChatField.value = "value"
            }
        }

        // You can choose to create the conversation when submiting
        // pre-chat values, otherwise the conversation will be started
        // after sending the first message.
        self.conversationClient?.submit(preChatFields: preChatFields, hiddenPreChatFields: [], createConversationOnSubmit: true)
    }

    /// Sets the debug level to see more logs in the console.
    private func setDebugLogging() {
        #if DEBUG
            Logging.level = .debug
        #endif
    }
}