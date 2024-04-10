// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SurveyRewardSystem {
    IERC20 public token;

    struct Survey {
        string ipfsHash;
        uint256 rewardPool;
        uint256 expectedRespondents;
        uint256 actualRespondents;
        address creator;
        bool exists;
        mapping(address => string) answers;
    }

    mapping(string => Survey) private surveys;

    event SurveyCreated(string ipfsHash, uint256 rewardPool, uint256 expectedRespondents, address creator);
    event SurveyAnswered(string surveyIpfsHash, address respondent, string answerIpfsHash);
    event SurveyCancelled(string surveyIpfsHash, address creator);

    constructor(IERC20 _token) {
        token = _token;
    }

    function createSurvey(string memory ipfsHash, uint256 singleReward, uint256 expectedRespondents) public {
        require(!surveys[ipfsHash].exists, "Survey already exists");
        require(expectedRespondents > 0, "Expected respondents must be greater than 0");
        uint256 rewardPool = singleReward * expectedRespondents;
        Survey storage survey = surveys[ipfsHash];
        survey.ipfsHash = ipfsHash;
        survey.rewardPool = rewardPool;
        survey.expectedRespondents = expectedRespondents;
        survey.actualRespondents = 0;
        survey.creator = msg.sender;
        survey.exists = true;
        require(token.transferFrom(msg.sender, address(this), rewardPool), "Failed to lock survey rewards");
        emit SurveyCreated(ipfsHash, rewardPool, expectedRespondents, msg.sender);
    }

    function answerSurvey(string memory surveyIpfsHash, string memory answerIpfsHash) public {
        require(surveys[surveyIpfsHash].exists, "Survey does not exist");
        // Check if the respondent's answer is an empty string, indicating they haven't answered yet
        require(bytes(surveys[surveyIpfsHash].answers[msg.sender]).length == 0, "Responder has already answered this survey");

        Survey storage survey = surveys[surveyIpfsHash];
        require(survey.actualRespondents < survey.expectedRespondents, "Survey has already reached its expected respondents");

        survey.answers[msg.sender] = answerIpfsHash;
        survey.actualRespondents++;

        uint256 rewardAmount = survey.rewardPool / survey.expectedRespondents;
        require(token.transfer(msg.sender, rewardAmount), "Failed to distribute reward");

        emit SurveyAnswered(surveyIpfsHash, msg.sender, answerIpfsHash);
    }

    function cancelSurvey(string memory surveyIpfsHash) public {
        require(surveys[surveyIpfsHash].exists, "Survey does not exist.");
        Survey storage survey = surveys[surveyIpfsHash];
        require(msg.sender == survey.creator, "Only the survey creator can cancel the survey.");
        
        uint256 remainingRewards = survey.rewardPool - (survey.rewardPool / survey.expectedRespondents * survey.actualRespondents);
        
        survey.exists = false;

        require(token.transfer(msg.sender, remainingRewards), "Failed to return remaining rewards.");
        
        emit SurveyCancelled(surveyIpfsHash, msg.sender);
    }
}
