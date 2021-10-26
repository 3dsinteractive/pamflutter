
//import './consent_message.dart';

class UserConsentPermissions {
    
    // String? consentID;
    // ConsentType? type;
    // String? consentMessageId;
    // int? version;
    // List<ConsentPermission>? permissions;
    // public let needToReview: Bool?
    // public let lastConsentVersion: Int?
    // public let contactID: String?
    // public let lastConsentAt: String?
    
    // private static func getType(type:String?)->ConsentType?{
    //     if(type == "tracking_type"){
    //         return  ConsentType.Tracking
    //     }else if(type == "contacting_type"){
    //         return  ConsentType.Contacting
    //     }
    //     return nil
    // }
    
    // static func parse(json: Json)-> UserConsentPermissions{
        
    //     let consentID = json[\.consent_id].string
        
    //     let type = getType(type: json[\.consent_message_type].string)
        
    //     let consentMessageId = json[\.consent_message_id].string
    //     let version = json[\.version].int
    //     let needToReview = json[\.need_consent_review].bool
    //     let lastConsentVersion = json[\.last_consent_version].int
        
    //     let permissions = parsePermission(json)
        
    //     let contactID = json[\.contact_id].string
    //     let lastConsentAt = json[\.last_consent_at].string
        
    //     return UserConsentPermissions(consentID: consentID,
    //                                   type: type,
    //                                   consentMessageId: consentMessageId,
    //                                   version: version,
    //                                   permissions: permissions,
    //                                   needToReview: needToReview,
    //                                   lastConsentVersion: lastConsentVersion,
    //                                   contactID: contactID,
    //                                   lastConsentAt: lastConsentAt)
    // }
    
    // private static func parsePermission(_ json:Json?)-> [ConsentPermission]{
    //     var list:[ConsentPermission] = []
        
    //     if let json = json?[\.tracking_permission].json {
            
    //         if let it = json[\.terms_and_conditions].bool {
    //             let perm = ConsentPermission(
    //                 name: .termsAndConditions,
    //                 shortDescription: nil,
    //                 fullDescription: nil,
    //                 fullDescriptionEnabled: false,
    //                 require: true,
    //                 allow: it)
    //             list.append(perm)
    //         }
            
    //         if let it = json[\.privacy_overview].bool {
    //             let perm = ConsentPermission(
    //                 name:.privacyOverview,
    //                 shortDescription: nil,
    //                 fullDescription: nil,
    //                 fullDescriptionEnabled: false,
    //                 require: true,
    //                 allow: it)
    //             list.append(perm)
    //         }
            
    //         if let it = json[\.necessary_cookies].bool {
    //             let perm = ConsentPermission(
    //                 name: .necessaryCookies,
    //                 shortDescription: nil,
    //                 fullDescription: nil,
    //                 fullDescriptionEnabled: false,
    //                 require: true,
    //                 allow: it)
    //             list.append(perm)
    //         }
            
    //         if let it = json[\.preferences_cookies].bool {
    //             let perm = ConsentPermission(
    //                 name: .preferencesCookies,
    //                 shortDescription: nil,
    //                 fullDescription: nil,
    //                 fullDescriptionEnabled: false,
    //                 require: true,
    //                 allow: it)
    //             list.append(perm)
    //         }
            
    //         if let it = json[\.analytics_cookies].bool {
    //             let perm = ConsentPermission(
    //                 name: .analyticsCookies,
    //                 shortDescription: nil,
    //                 fullDescription: nil,
    //                 fullDescriptionEnabled: false,
    //                 require: false,
    //                 allow: it)
    //             list.append(perm)
    //         }
            
    //         if let it = json[\.marketing_cookies].bool {
    //             let perm = ConsentPermission(
    //                 name: .marketingCookies,
    //                 shortDescription: nil,
    //                 fullDescription: nil,
    //                 fullDescriptionEnabled: false,
    //                 require: false,
    //                 allow: it)
    //             list.append(perm)
    //         }
            
    //         if let it = json[\.socialMedia_cookies].bool {
    //             let perm = ConsentPermission(
    //                 name: .socialMediaCookies,
    //                 shortDescription: nil,
    //                 fullDescription: nil,
    //                 fullDescriptionEnabled: false,
    //                 require: false,
    //                 allow: it)
    //             list.append(perm)
    //         }
            
    //     }
        
    //     if let json = json?[\.contacting_permission].json {
            
    //         if let it = json[\.email].bool {
    //             let perm = ConsentPermission(
    //                 name: .email,
    //                 shortDescription: nil,
    //                 fullDescription: nil,
    //                 fullDescriptionEnabled: false,
    //                 require: false,
    //                 allow: it)
    //             list.append(perm)
    //         }
            
    //         if let it = json[\.sms].bool {
    //             let perm = ConsentPermission(name: .sms,
    //                                          shortDescription: nil,
    //                                          fullDescription: nil,
    //                                          fullDescriptionEnabled: false,
    //                                          require: false,
    //                                          allow: it)
    //             list.append(perm)
    //         }
            
    //         if let it = json[\.line].bool {
    //             let perm = ConsentPermission(name: .line,
    //                                          shortDescription: nil,
    //                                          fullDescription: nil,
    //                                          fullDescriptionEnabled: false,
    //                                          require: false,
    //                                          allow: it)
    //             list.append(perm)
    //         }
            
    //         if let it = json[\.facebook_messenger].bool {
    //             let perm = ConsentPermission(name: .facebookMessenger,
    //                                          shortDescription: nil,
    //                                          fullDescription: nil,
    //                                          fullDescriptionEnabled: false,
    //                                          require: false,
    //                                          allow: it)
    //             list.append(perm)
    //         }
            
    //         if let it = json[\.push_notification].bool {
    //             let perm = ConsentPermission(name: .pushNotification,
    //                                          shortDescription: nil,
    //                                          fullDescription: nil,
    //                                          fullDescriptionEnabled: false,
    //                                          require: false,
    //                                          allow: it)
    //             list.append(perm)
    //         }
            
    //     }
        
    //     return list
    // }
}
