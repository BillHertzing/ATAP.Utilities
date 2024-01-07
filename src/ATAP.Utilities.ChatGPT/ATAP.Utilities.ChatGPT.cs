using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using Microsoft.VisualStudio.ExtensionManager;
using Microsoft.VisualStudio.Shell;
using Microsoft.VisualStudio.Shell.Interop;
using Microsoft.Speech.Recognition;
using ChatGPT;

namespace VSCodeVoiceInputExtension
{
    public class VoiceInputExtension : IExtension
    {
        private SpeechRecognitionEngine _speechRecognizer;
        private ChatGPTClient _chatGPTClient;

        public void Initialize(IVsExtensionManager extensionManager)
        {
            // Initialize the speech recognition engine
            _speechRecognizer = new SpeechRecognitionEngine();
            _speechRecognizer.SetInputToDefaultAudioDevice();
            _speechRecognizer.LoadGrammar(new DictationGrammar());
            _speechRecognizer.SpeechRecognized += OnSpeechRecognized;
            _speechRecognizer.RecognizeAsync(RecognizeMode.Multiple);

            // Initialize the ChatGPT client
            _chatGPTClient = new ChatGPTClient();
        }

        private void OnSpeechRecognized(object sender, SpeechRecognizedEventArgs e)
        {
            // Get the input string from the speech recognition engine
            string inputString = e.Result.Text;

            // Send the input string to ChatGPT and get the response
            string responseString = _chatGPTClient.SendMessage(inputString);

            // Create a new editor window in Visual Studio Code
            IVsNewDocumentStateContext newDocStateContext = (IVsNewDocumentStateContext)Package.GetGlobalService(typeof(SVsNewDocumentStateContext));
            newDocStateContext.NewDocumentState = __VSNEWDOCUMENTSTATE.NDS_Provisional;
            IVsUIShellOpenDocument openDoc = (IVsUIShellOpenDocument)Package.GetGlobalService(typeof(SVsUIShellOpenDocument));
            Guid logicalView = VSConstants.LOGVIEWID_Primary;
            IVsWindowFrame frame;
            openDoc.OpenDocumentViaProject("Untitled-1", ref logicalView, out frame);

            // Put the response string into the new editor window
            object docData;
            frame.GetProperty((int)__VSFPROPID.VSFPROPID_DocData, out docData);
            IVsTextLines textLines = (IVsTextLines)docData;
            textLines.SetText(responseString);
        }
    }
}
