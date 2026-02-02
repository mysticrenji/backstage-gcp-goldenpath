import streamlit as st
import vertexai
from vertexai.generative_models import GenerativeModel

# Configuration
PROJECT_ID = "${{ values.gcp_project_id }}"
REGION = "${{ values.gcp_region }}"
MODEL_ID = "gemini-1.5-flash"

# Page config
st.set_page_config(
    page_title="${{ values.component_id }}",
    page_icon="🤖",
    layout="wide"
)

st.title("🤖 ${{ values.component_id }}")
st.caption("Deployed via the AI Golden Path")


# Initialize Vertex AI
@st.cache_resource
def init_vertex_ai():
    vertexai.init(project=PROJECT_ID, location=REGION)
    return GenerativeModel(MODEL_ID)


# Initialize chat session
@st.cache_resource
def get_chat_session(_model):
    return _model.start_chat()


# Main app
def main():
    # Initialize model
    try:
        model = init_vertex_ai()
        chat = get_chat_session(model)
        st.success("Connected to Vertex AI")
    except Exception as e:
        st.error(f"Failed to initialize Vertex AI: {e}")
        st.info("Make sure you have the correct permissions and the API is enabled.")
        return

    # Chat interface
    if "messages" not in st.session_state:
        st.session_state.messages = []

    # Display chat history
    for message in st.session_state.messages:
        with st.chat_message(message["role"]):
            st.markdown(message["content"])

    # Chat input
    if prompt := st.chat_input("Ask me anything..."):
        # Add user message
        st.session_state.messages.append({"role": "user", "content": prompt})
        with st.chat_message("user"):
            st.markdown(prompt)

        # Get AI response
        with st.chat_message("assistant"):
            with st.spinner("Thinking..."):
                response = chat.send_message(prompt)
                st.markdown(response.text)
                st.session_state.messages.append({
                    "role": "assistant",
                    "content": response.text
                })


if __name__ == "__main__":
    main()
